# ODRAVETH — AI Design (Stage 3)

## 1. Цель

Stage 3 реализует полностью локального, детерминированного и объяснимого соперника для офлайн-матча. AI не является вторым rules engine: он получает допустимые команды от MatchEngine, оценивает их и исполняет выбранную команду через MatchEngine.

Уровни: NOVICE / Новичок, TACTICIAN / Тактик, STRATEGIST / Стратег.

## 2. Information boundary

Единственный вход состояния для production AI — MatchEngine.get_observation(viewer_player).

Собственная сторона раскрывает hero, energy, Soul Shards, Impulse Shard, hero-power state, собственную руку, board, artifact, graveyard, hand/deck count и публичные modifiers.

Сторона противника раскрывает hero, публичные resources, board, artifact, graveyard, hand count, deck count и публичные modifiers.

Никогда не выдаются opponent hand identities, identity/order карт любой колоды, будущий draw, будущая random target, RNG state, MatchResolver, WHEN/AFTER queues, delayed internal actions и canonical snapshot().

Если MatchEngine реально открыл владельцу выбор CHOOSE, observation содержит definitions только этих раскрытых options.

## 3. Детерминизм

AiController.decide(observation, legal_commands) не использует RNG.

Кандидаты сортируются сначала по total score по убыванию, затем по canonical command key по возрастанию. Ключ содержит kind, source_id, target_id, отсортированные mulligan ids и canonical choices.

## 4. Scoring

Score — сумма именованных integer-components: LETHAL, HERO_DAMAGE, BOARD_VALUE, TRADE_VALUE, THREAT_REMOVAL, PRESERVE_CREATURE, CARD_ADVANTAGE, ENERGY_EFFICIENCY, RESOURCE_VALUE, SYNERGY, OVERDRAW_RISK, BOARD_SPACE, SELF_DAMAGE_RISK, PUBLIC_THREAT, WASTED_DAMAGE, HERO_POWER, END_TURN и другие локальные компоненты.

Карты оцениваются generic по CardDefinition, CardEffectSpec, actions/conditions и публичному runtime state. Отдельных ветвей для 40 card_id нет. Hero powers оцениваются отдельно через HeroCatalog.

## 5. Сложности

NOVICE: одна текущая legal-команда, без lookahead; сильнее весит простой урон и базовые stats, слабее — ресурсы, triggers и board planning. Immediate lethal обязателен.

TACTICIAN: дополнительно оценивает размены, threat removal, сохранение существ, armor, board/card advantage, hand limit, artifact/Soul Shard/hero-power value, Deferral/Echo/cost disruption и публичную угрозу.

STRATEGIST: всё тактическое плюс sequencing текущего хода, generic synergy собственной видимой руки, board/hand space, resource preservation и tempo/value. Дополнительной информации не получает.

## 6. Mulligan

MatchEngine генерирует legal mulligan subsets. Policy не смотрит результат замены.

Novice — стартовая стоимость. Tactician — curve + generic card value. Strategist — curve + value + synergy уже видимой руки.

## 7. CHOOSE и Cartographer

При pending choice controller получает только legal CHOOSE commands и раскрытые options. Novice оценивает simple card value; Tactician — value + текущую ситуацию; Strategist — ещё и synergy собственной видимой руки.

## 8. Soulmonger

Каждый soul_shards_to_spend от 0 до min(3, shards) — отдельная legal command. Generic evaluator оценивает stats/armor и стоимость ресурса. Strategist сильнее сохраняет Soul Shards при отсутствии публичного давления.

## 9. Hero powers и Impulse Shard

Kezharyn получает большой self-lethal penalty; Vhorazel учитывает место до cap 10; Syrraveth оценивает disruption без чтения opponent hand; Tazhyrion оценивает видимую friendly target.

Impulse Shard получает положительную ценность, когда +1 энергии открывает видимую карту или hero power. Tactician/Strategist штрафуют бессмысленный расход сильнее Novice.

## 10. Full-turn loop

AiTurnRunner получает observation и legal commands, выбирает команду, проверяет legal membership и validate(), исполняет через execute(), затем повторяет на новом observation.

MAX_AI_COMMANDS_PER_TURN = 64. При достижении лимита и отсутствии pending choice выполняется legal END_TURN. После outcome новых команд нет.

## 11. Explainability

AiDecision хранит difficulty, selected command, total score, components, candidate count и optional ranked candidates. Ranked trace включается только debug/test кодом. Скрытая информация в trace не попадает.

## 12. Anti-cheat tests

Пары матчей с одинаковым observation и различной opponent hand identity, opponent deck order, own future deck order и RNG state обязаны давать одинаковую команду. После фактического draw новая own-hand карта уже может изменить решение. Source audit запрещает production AI private-state/RNG обращения.

## 13. QA harness и stress

tests/ai/ai_match_harness.gd запускает реальные AI-vs-AI матчи через MatchEngine. Test decks — fixture decks в tests, не продуктовые presets. CI проверяет героев, сложности, first/second player, fixed-seed stress и targeted mutations.

## 14. Ограничения Stage 3

Нет minimax/game tree, hidden-information belief model, opponent-hand inference, ML/neural network, сетевого AI и финального Battle UI. Evaluator — bounded heuristic AI, рассчитанный в том числе на Android.
