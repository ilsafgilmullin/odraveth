# Stage 7 — Prebattle V3, random opponent and Opponent Search

Presentation and setup flow only: MatchEngine, AI, the 40 cards and the v2 save schema are unchanged.

## Prebattle V3

Three panels over the Visual Alpha Citadel hall backdrop:

- **ВАШ ГЕРОЙ** — temporary portrait, name, faction symbol, hero power and cost, **СМЕНИТЬ ГЕРОЯ**;
- **ВАША КОЛОДА** — name of the selected ready deck, `30/30` with **✓ ГОТОВА**, cost curve, composition, **СМЕНИТЬ КОЛОДУ** (or **СОБРАТЬ КОЛОДУ** when no ready deck exists);
- **СЛОЖНОСТЬ** — segmented **НОВИЧОК / ТАКТИК / СТРАТЕГ** (selected = filled + check icon) with the approved principle of each level, and **ПОДАЧА БОЯ** — switches **Подсказки / Анимации / Прогноз урона**.

Main action: **НАЙТИ СОПЕРНИКА** (disabled without a ready selected deck). There is no manual opponent selection.

Switches use Visual Alpha icons (`switch_on.svg` / `switch_off.svg`): knob position and a check mark carry the state, not colour alone. All three toggles persist locally, default ON, and only change presentation (`BattleLaunchConfig.presentation_options`); MatchEngine, AI and RNG never read them.

## Random opponent

`OpponentSelector` picks a concrete hero with integer weights out of 1000: exact same `hero_id` 100 (~10 %), the remaining 900 shared equally by the other eligible heroes in canonical order. Several heroes per faction are supported; a mirror is only the identical `hero_id`. Prebattle draws with a fresh setup seed (`BattleLaunchConfig.generate_seed()`) through its own `DeterministicRng` (the injectable `MatchRng` abstraction, a separate instance from the match RNG) — then builds the `BattleLaunchConfig` (exact deck snapshot, deck name/id metadata, difficulty, presentation options, fresh match seed).

## Opponent Search

`Routes.OPPONENT_SEARCH` → `OpponentSearchScreen` with `CitadelMechanismView`: stone outer ring with four faction seals, counter-rotating steel and gold rings, a luminous central window and a restrained activation light.

Sequence: (1) the opponent is already in the config; (2) activation light; (3) faction symbols cycle in the window while the matching seal lights; (4) the cycle slows; (5) the mechanism locks on the drawn faction. Only **СОПЕРНИК НАЙДЕН** and the faction are shown — no hero portrait or name. **К БОЮ** (or auto-continue) replaces the search with Battle; a tap skips to the locked result; Back cancels to Prebattle. With **Анимации** OFF the same locked result is shown immediately.

## Verification

`tests/prebattle_v3_tests.gd`: weights (mirror 10 %, equal shares, multiple heroes per faction), 20 000-draw distribution, seed determinism, no global RNG, controls/persistence, missing-deck guard, developer-word audit, responsive containment at four sizes, reveal contract for all four opponents (sequence ends on the drawn faction, config and seed untouched, no hero name/portrait), animations OFF, and the real route flow Prebattle → Search → Back/restart → Battle.
