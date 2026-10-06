extends Control
## Main menu — Stage 0 technical placeholder, not the final approved UI.
## Buttons and their order follow docs/PRODUCT_BASELINE.md section 8; the target
## of every button is a technical mapping (docs/DECISIONS.md, D-009).


func _ready() -> void:
	var routes_by_button := {
		%CollectionButton: Routes.COLLECTION,
		%DecksButton: Routes.DECK_BUILDER,
		%HeroesButton: Routes.HERO_SELECT,
		%ProgressButton: Routes.PROGRESS,
		%SettingsButton: Routes.SETTINGS,
	}
	for button: Button in routes_by_button:
		button.pressed.connect(SceneRouter.go_to.bind(routes_by_button[button]))
	%PlayButton.pressed.connect(_play)


func _play() -> void:
	var route := Routes.PREBATTLE if PlayerSetupData.selected_deck(AppState.profile, CardDatabase) != null else Routes.DECK_BUILDER
	SceneRouter.go_to(route)
