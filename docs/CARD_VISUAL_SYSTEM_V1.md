# Stage 7D — Card Visual System V1 + Card Detail V1

Stage 7D is presentation infrastructure only. The 40 gameplay definitions, balance, MatchEngine, AI, DeckValidator, BattleSession and save semantics are unchanged.

## Architecture

- `CardPresentation` converts a read-only `CardDefinition` into presentation fields. Numeric mechanics remain sourced from `CardDefinition`; labels come from existing enums/SetupUi.
- `CardFactionPresentation` owns restrained card accent colours and delegates faction labels to `SetupUi`.
- `CardArtResolver` resolves **exact card ID → individual art resource** under `res://assets/cards/<card_id>.(webp|png|svg)`. It never falls back to one generic faction/type illustration.
- `CardArtSlot` renders resolved art with aspect-cover behavior or an explicit deterministic **АРТ · ВРЕМЕННО** fallback.
- `RarityMark` uses distinct geometry for Common/Rare/Epic/Legendary, not colour alone.
- `CardFrameVisual` draws the ODRAVETH architectural cut-corner silhouette. CURSE already has a fracture/asymmetry presentation variant without adding Curse gameplay.
- `FullCardView` is the canonical reusable FULL CARD component; `scenes/common/full_card_view.tscn` is its reusable packed-scene entrypoint.
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


## Originality audit

The Stage 7D shell deliberately avoids Hearthstone-specific visual grammar:

- outer silhouette is an architectural cut-corner polygon rather than an ornate oval/scroll frame;
- artwork is a large rectangular architectural slot, never a circular minion window;
- Energy cost uses a dark steel rectangular plate, not a blue crystal;
- attack/health are restrained labelled plates, not opposing coloured gems;
- armor and artifact charges use their own labelled treatment;
- rarity is a small geometry mark in the metadata row rather than a central gem;
- Legendary uses a restrained multifaceted old-gold seal with no crown/dragon motif.

This is a structural audit of the implemented component grammar; final illustration art is still deferred.

## Stage 7D verification

Checkpoint validation requires:

- official Godot 4.7.2 stable;
- fresh checkout with no pre-existing `.godot/`;
- error-free import of Stage 7A typography/theme, Stage 7B Main Menu, Stage 7C Hero Select and Stage 7D card resources;
- runtime construction of all 40 authoritative starter definitions;
- creature/spell/artifact type invariants plus synthetic presentation-only CURSE coverage;
- four rarity geometry identities and five faction groups;
- long-name and long-rules semantic wrapping checks;
- reusable FullCard packed scene and normal/selected/disabled/pressed/focus states;
- exact-card artwork resolver with safe non-final fallback;
- responsive Card Detail at 1600×900, 1920×1080, 2400×1080 and 2800×1752;
- System Back closes Card Detail before route navigation;
- repeated detail switching and 30-card create/destroy batch without retained nodes;
- clean re-import after deleting `.godot/`;
- one full project regression at the checkpoint.
