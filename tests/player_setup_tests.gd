extends RefCounted
## Stage 5 persistence and rule-authority checks, run by smoke_test.

var check: Callable
var cards: CardDatabase


func _init(check_fn: Callable, card_source: CardDatabase) -> void:
	check = check_fn
	cards = card_source


func run() -> void:
	cards.load_directory()
	var defaults := SaveManager.create_default_data()
	check.call(SaveManager.CURRENT_SAVE_VERSION == 2, "Stage 5 save schema version 2")
	check.call(defaults["prebattle"][PlayerSetupData.HINTS] == true
		and defaults["prebattle"][PlayerSetupData.ANIMATIONS] == true
		and defaults["prebattle"][PlayerSetupData.FORECAST] == true, "three presentation toggles default ON")
	check.call(defaults["user_decks"].is_empty() and defaults["selected_deck_id"] == "", "fresh save has no preset deck")
	check.call(SetupUi.faction_name(Faction.Id.NEUTRAL) == "Нейтральные", "official Neutral UI label")
	check.call(cards.get_card_count() == 40, "starter collection has all 40 cards")
	check.call(PlayerSetupData.HERO_IDS.size() == 4 and PlayerSetupData.HERO_IDS.all(func(id: StringName) -> bool:
		return HeroCatalog.has_hero(id)), "four approved hero identities")
	var manager := SaveManager.new("user://odraveth_smoke_test/stage5_migration.json")
	var old := {"save_version": 1, "old_field": {"kept": true}}
	var migrated := manager.migrate(old, 1)
	check.call(migrated["save_version"] == 2 and migrated["old_field"]["kept"], "v1 migration preserves old fields")
	check.call(migrated["prebattle"][PlayerSetupData.FORECAST] == true, "v1 migration supplies preference defaults")
	var legacy_file := FileAccess.open(manager.save_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(old))
	legacy_file.close()
	var legacy_loaded := manager.load_data()
	check.call(manager.last_load_status == SaveManager.LoadStatus.OK and legacy_loaded["save_version"] == 2
		and legacy_loaded["old_field"]["kept"], "legacy v1 file loads with migrated fields")
	var selected := PlayerSetupData.select_hero(defaults, HeroCatalog.KEZHARYN)
	check.call(selected["selected_hero_id"] == String(HeroCatalog.KEZHARYN), "hero selection updates profile")
	var deck := UserDeck.create(HeroCatalog.KEZHARYN)
	check.call(deck.id.begins_with("deck_") and deck.name == "Новая колода", "new deck has stable local ID and neutral name")
	var cards30 := BattleLaunchConfig.technical_opponent_deck(HeroCatalog.KEZHARYN, cards)
	check.call(DeckValidator.validate(deck.hero_id, cards30, cards).is_empty(), "test deck is validated by DeckValidator")
	deck.card_ids.assign(cards30)
	check.call(deck.is_ready(cards), "ready status delegates to DeckValidator")
	var profile := PlayerSetupData.upsert(selected, deck, cards)
	check.call(profile["selected_deck_id"] == deck.id, "first ready deck selected")
	check.call(PlayerSetupData.selected_deck(profile, cards).card_ids == deck.card_ids, "selected deck resolves exact card IDs")
	check.call(manager.write_data(profile) == OK, "profile writes multiple-deck schema")
	var disk_profile := SaveManager.new(manager.save_path).load_data()
	check.call(disk_profile["selected_hero_id"] == String(deck.hero_id) and disk_profile["selected_deck_id"] == deck.id
		and disk_profile["user_decks"].size() == 1, "selected hero/deck survive disk restart")
	var second := UserDeck.create(HeroCatalog.KEZHARYN)
	second.name = "Другая"
	second.card_ids.assign(cards30)
	profile = PlayerSetupData.upsert(profile, second, cards)
	check.call(profile["user_decks"].size() == 2 and second.id != deck.id, "multiple distinct decks retained")
	check.call(manager.write_data(profile) == OK
		and SaveManager.new(manager.save_path).load_data()["user_decks"].size() == 2,
		"multiple decks survive disk restart")
	second.name = "Изменена"
	profile = PlayerSetupData.upsert(profile, second, cards)
	check.call(profile["user_decks"].size() == 2 and PlayerSetupData.decks_for(profile, HeroCatalog.KEZHARYN)[1].name == "Изменена", "save updates existing ID")
	var draft := UserDeck.create(HeroCatalog.KEZHARYN)
	draft.card_ids.assign(cards30.slice(0, 29))
	profile = PlayerSetupData.upsert(profile, draft, cards)
	check.call(profile["user_decks"].size() == 3 and not draft.is_ready(cards), "invalid 29-card draft can persist")
	check.call(manager.write_data(profile) == OK and SaveManager.new(manager.save_path).load_data()["user_decks"].size() == 3,
		"invalid draft survives disk restart")
	check.call(profile["selected_deck_id"] == deck.id, "draft does not replace selected ready deck")
	var other_hero := PlayerSetupData.select_hero(profile, HeroCatalog.VHORAZEL)
	check.call(other_hero["selected_deck_id"] == "" and PlayerSetupData.selected_deck(other_hero, cards) == null,
		"hero change deactivates incompatible deck")
	check.call(other_hero["user_decks"].size() == 3 and other_hero["user_decks"][0]["hero_id"] == String(HeroCatalog.KEZHARYN),
		"hero change keeps existing faction decks unchanged")
	var loaded := PlayerSetupData.normalized(other_hero)
	check.call(loaded["user_decks"].size() == 3 and loaded["selected_hero_id"] == String(HeroCatalog.VHORAZEL),
		"restart normalization restores multiple decks and hero")
	loaded["prebattle"][PlayerSetupData.ANIMATIONS] = false
	check.call(PlayerSetupData.normalized(loaded)["prebattle"][PlayerSetupData.ANIMATIONS] == false,
		"preference false survives normalization")
	check.call(manager.write_data(loaded) == OK
		and SaveManager.new(manager.save_path).load_data()["prebattle"][PlayerSetupData.ANIMATIONS] == false,
		"presentation preference survives disk restart")
	draft.name = "  "
	check.call(not draft.is_ready(cards) and not draft.name_problem().is_empty(), "blank deck names rejected")
	draft.name = "А".repeat(UserDeck.MAX_NAME_LENGTH + 1)
	check.call(not draft.name_problem().is_empty(), "local deck name length bounded")
	var bad := PlayerSetupData.normalized({"user_decks": [null, 17, {"id": "bad", "name": "X", "hero_id": "INVALID", "card_ids": []}],
		"prebattle": {PlayerSetupData.HINTS: "false"}})
	check.call(bad["user_decks"].is_empty() and bad["prebattle"][PlayerSetupData.HINTS] == true,
		"corrupt records and wrong preference types sanitized")
	var unknown := deck.to_data()
	unknown["card_ids"] = ["not_an_approved_card"]
	var unknown_profile := PlayerSetupData.normalized({"selected_hero_id": String(deck.hero_id),
		"selected_deck_id": deck.id, "user_decks": [unknown]})
	check.call(unknown_profile["user_decks"].size() == 1 and PlayerSetupData.selected_deck(unknown_profile, cards) == null,
		"unknown card is retained as invalid draft and cannot launch")
	var unsafe_object := Object.new()
	check.call(UserDeck.from_data({"id": "x", "name": "X", "hero_id": String(deck.hero_id),
		"card_ids": [unsafe_object]}) == null, "save rejects object instances in card arrays")
	unsafe_object.free()
	check.call(not BattleLaunchConfig.technical_opponent_deck(HeroCatalog.TAZHYRION, cards).is_empty(),
		"temporary opponent deck source available without product preset name")
	var cfg := BattleLaunchConfig.create(deck.hero_id, deck.card_ids, HeroCatalog.VHORAZEL,
		BattleLaunchConfig.technical_opponent_deck(HeroCatalog.VHORAZEL, cards), AiDifficulty.Level.TACTICIAN,
		0, {PlayerSetupData.ANIMATIONS: false})
	deck.card_ids.clear()
	check.call(cfg.player_deck.size() == 30 and cfg.presentation_options[PlayerSetupData.ANIMATIONS] == false,
		"launch owns player deck snapshot and presentation choices")
	var unique_seeds: Dictionary = {}
	for _i in 100:
		var fresh := BattleLaunchConfig.create(cfg.player_hero, cfg.player_deck, cfg.opponent_hero,
			cfg.opponent_deck, cfg.ai_difficulty)
		unique_seeds[fresh.rng_seed] = true
	check.call(unique_seeds.size() == 100, "rapid rematches receive distinct generated seeds")
	var source := FileAccess.get_file_as_string("res://scripts/ui/prebattle_screen.gd")
	check.call(not source.contains("technical_dev_config"), "normal Prebattle never calls technical player config")
	cards.free()
