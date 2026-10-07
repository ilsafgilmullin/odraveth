# Stage 7D — Card Visual System V1 + Card Detail V1

Stage 7D is presentation infrastructure only. The 40 gameplay definitions, balance, MatchEngine, AI, DeckValidator, BattleSession and save semantics are unchanged.

## Architecture

- `CardPresentation` converts a read-only `CardDefinition` into presentation fields. Numeric mechanics remain sourced from `CardDefinition`; labels come from existing enums/SetupUi.
- `CardFactionPresentation` owns restrained card accent colours and delegates faction labels to `SetupUi`.
- `CardArtResolver` resolves **exact card ID → individual art resource** under `res://assets/cards/<card_id>.(webp|png|svg)`. It never falls back to one generic faction/type illustration.
- `CardArtSlot` renders resolved art with aspect-cover behavior or an explicit deterministic **АРТ · ВРЕМЕННО** fallback.
- `RarityMark` uses distinct geometry for Common/Rare/Epic/Legendary, not colour alone.
- `CardFrameVisual` draws the ODRAVETH architectural cut-corner silhouette. CURSE already has a fracture/asymmetry presentation variant without adding Curse gameplay.
- `FullCardView` is the canonical reusable FULL CARD component.
- `CardDetailOverlay` remains backward-compatible with existing callers while adding `open_card(card_id/definition)` and structured detail UI.

## Full Card anatomy

Approximate ratio is 5:7.

- top-left: architectural Energy cost plate;
- upper/central: individual artwork slot/fallback;
- Russian name;
- type + rarity geometry/label;
- wrapped authoritative Russian rules;
- type-specific lower stats.

Creature: attack + health, and armor only when base armor > 0.

Spell: no fake combat stats.

Artifact: dedicated charge badge, no creature attack/health.

Curse: common base grammar with disrupted lower-corner/fracture geometry reserved for future approved Curse content.

## Detail

Card Detail uses a responsive Stage 7A modal. Left: enlarged `FullCardView`. Right: Russian name, English reference name, faction/type/rarity/cost, only relevant stats, full rules and structured keyword markers.

Existing `show_card(CardDefinition, current_cost)` remains supported for Collection/Deck Builder/Battle. New callers may use `open_card(card_id/definition)`.

## Future mode contract

Compact Battle Card and Board Piece are not implemented in Stage 7D. They should consume the same `CardPresentation`, `CardArtResolver`, faction and rarity presentation layers rather than creating another card database or art lookup.

## Art status

**FINAL CARD ART IS NOT PRESENT.** No random final-looking illustrations were generated. Every missing exact-card artwork resolves safely to a visibly non-final Citadel/geometric fallback.
