# Stage 7E — Collection V1 / Archive of Nulmeris

Collection V1 is a read-only browser over the authoritative `CardDatabase`. It introduces no ownership, crafting, economy, deck-building or gameplay state.

## Architecture

- `CollectionFilterState` owns normalized RU/EN search and FACTION / TYPE / RARITY / COST predicates.
- `CollectionScreen` owns controls, responsive grid lifecycle and transient browser state.
- Every card tile is the Stage 7D `FullCardView`.
- Every enlarged view is the Stage 7D `CardDetailOverlay`.
- `CollectionArchiveBackdrop` is a cheap static Citadel/archive frame around the browsing surface; it has no per-frame processing.

The source set is `CardDatabase.get_all_cards()`. Its deterministic ID order is retained as the default Collection order, so no second catalogue or visible Sort feature is introduced.

## Search

Search is immediate on text change, trims surrounding whitespace and performs case-insensitive partial matching against both `name_ru` and `name_en`.

The Search clear affordance is independent from **СБРОСИТЬ**. Filter reset clears FACTION / TYPE / RARITY / COST only and intentionally preserves the current search query.

## Filters

Filters combine with logical AND and with Search.

- FACTION: ВСЕ, АШРАВАЙЛЬ, НЕРКАТЕН, ДУМОРИСС, КЕВАРУУН, НЕЙТРАЛЬНЫЕ.
- TYPE: current non-empty categories only. The current set exposes СУЩЕСТВА, ЗАКЛИНАНИЯ and АРТЕФАКТЫ; CURSE remains supported by the enum/presentation architecture but is not shown while the catalogue has zero Curse cards.
- RARITY: ВСЕ, ОБЫЧНЫЕ, РЕДКИЕ, ЭПИЧЕСКИЕ, ЛЕГЕНДАРНЫЕ.
- COST: ВСЕ, 0–1, 2, 3, 4, 5, 6, 7+.

Selected dropdown text plus the **АКТИВНО: N** summary make active filters explicit without relying on colour.

## Responsive grid

Collection uses the Stage 7A responsive foundation via the size-aware helper `ResponsiveLayout.collection_columns_for_size()`.

Validated policy:

- 1600×900 → 4 columns.
- 1920×1080 → 5 columns.
- 2400×1080 → 5 columns (very-wide phone-shaped viewport, not treated as a tablet).
- 2800×1752 → 6 columns (tablet/large-landscape profile).

The legacy width-only Stage 7A helper remains unchanged for older consumers.

FullCard retains its Stage 7D minimum 320×448 rather than shrinking typography to force density.

## Detail / scrolling

Whole-card activation opens the shared Card Detail; no separate info button exists. Closing Detail or handling Android/System Back closes the overlay first and leaves the Collection grid and scroll position intact.

Search focus gets the next Back priority: Collection releases the field focus and requests the platform virtual keyboard to hide before route navigation.

Physical Android IME resizing/dismissal cannot be proven by headless CI and remains a final real-device QA item.

## Performance / lifecycle

There is no per-frame Collection or FullCard rebuild. Search/filter changes rebuild the small current result set only when state changes. `CardArtResolver` caches exact-card path/texture resolution, including missing-art results, so repeated filter rebuilds do not repeat filesystem/resource lookup for the same IDs.

The current 40-card catalogue does not justify pooling/virtualization. Runtime stress covers repeated queries, filters, reset, detail switching, route cycles and bounded card-node populations.

## Art status

Final unique card illustrations are still deferred. Stage 7D exact-card resolver/fallback behavior remains visible and explicit; Collection does not disguise placeholder art as final production art.
