# Stage 7 — Deck Builder V1

Deck Builder V1 is presentation and setup-flow work. `DeckValidator` (through `UserDeck.is_ready()` / `problems()`) remains the only readiness authority; MatchEngine, cards, AI and the v2 save schema are unchanged.

## Structure

- Title row: **НАЗАД**, **РЕДАКТОР КОЛОДЫ**, **СМЕНИТЬ ГЕРОЯ**.
- Common header (`DeckIdentityBar`): selected hero (temporary portrait + name), faction with its symbol, editable deck name, **N / 30**, readiness marker **ГОТОВА / НЕ ГОТОВА** (text + geometry, not colour only) and **✓ ВЫБРАНА ДЛЯ БОЯ** when the open deck is the active one.
- Tabs **КАРТЫ | КОЛОДА · N/30**. Only one page is visible at a time — the cramped permanent split view of Stage 5 is gone. On КАРТЫ the same row carries the filter toolbar (wraps to a second line on narrow canvases).
- Footer: saved-deck selector, **НОВАЯ**, action status, **ОЧИСТИТЬ**, **СОХРАНИТЬ**, **ВЫБРАТЬ**.

## КАРТЫ

Reuses `CardDatabase`, the Stage 7D `FullCardView`, `CardDetailOverlay` and the Stage 7E `CollectionFilterState` predicates (`CardFilterBar`). Only the selected hero's faction and **НЕЙТРАЛЬНЫЕ** are offered (16 cards). Each card has large **− / N / limit / +** controls (≥ 84×64 design px); a whole-card tap opens Card Detail. Columns follow `ResponsiveLayout.collection_columns_for_size()`; on device-shaped canvases (≥ 1080 high) the first row and its controls are fully visible without scrolling.

## КОЛОДА

Rows sorted by cost then name: cost plate, faction stripe, name + type/rarity (tap → Card Detail), **−**, ×copies, **+**. A summary panel shows the cost curve (0–1 … 7+), composition by type and readiness guidance in Russian. Copy/size limits pre-disable buttons only; readiness and the **ВЫБРАТЬ** action always go through `DeckValidator`.

## Confirmation and Back

**ОЧИСТИТЬ** uses the Visual Alpha `ConfirmModal` (no default Godot dialog). Back priority: confirmation → Card Detail → deck-name keyboard focus → route navigation.

## Hero ↔ deck invariant

Covered by `tests/deck_builder_v1_tests.gd`: a ready Kezharyn deck exists → switching to Syrraveth (same `PlayerSetupData.select_hero` path as Hero Select confirmation) keeps the Kezharyn record stored and unchanged, clears the active selection, makes it non-launchable and invisible in Syrraveth's builder → switching back preserves the stored deck, which reopens for explicit re-selection. There is no silent cross-hero launch.

## Verification

`tests/deck_builder_v1_tests.gd` (also part of the full smoke run) checks tabs, card scope, copy controls, deck rows, detail, Back priority, the invariant and responsive containment at 1600×900, 1920×1080, 2400×1080 and 2800×1752. `tests/player_setup_ui_tests.gd` keeps the Stage 5 add/remove/save/select/clear semantics.
