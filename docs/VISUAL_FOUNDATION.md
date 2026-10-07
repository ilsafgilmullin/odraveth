# Stage 7A — Visual Foundation / UI Kit

Stage 7A is presentation infrastructure only. It does not change MatchEngine, cards, AI, persistence semantics, DeckValidator, or BattleSession rules.

## Direction

The reusable palette models the light ancient Citadel of Nulmeris: aged grey-beige stone, dark steel, matte old gold, and restrained blue/turquoise magical accents.

The Visual Alpha theme resource is `res://assets/ui/visual_alpha/theme/visual_alpha_theme.tres`.

The asset-free `placeholder_theme.tres` remains the ProjectSettings bootstrap theme. This is deliberate: Godot initializes the project theme before a brand-new `.godot/imported` cache exists. Stage screens opt into the Visual Alpha theme through `UiKit.apply_root_theme()` after import, avoiding bootstrap errors without copying cache files.

## Typography

- Display/title: Noto Serif SemiBold.
- UI/body: Noto Serif Regular.
- Both files are bundled locally and covered by SIL Open Font License 1.1.
- Upstream snapshot and license note live beside the font files.

The family was selected for readable full Cyrillic coverage. Stage 7A tests verify representative Cyrillic glyphs through Godot itself.

## Shared metrics

`VisualTokens` is the palette/spacing/type/touch source of truth.

`ResponsiveLayout` defines shared width classes and layout metrics. The foundation prepares 4/5/6-column responsive content behavior and explicitly covers 1920×1080 and 2400×1080 landscape without binding screens to one exact width.

## UI kit

`UiKit` provides reusable presentation primitives for primary, secondary, subtle, compact battle and icon buttons; filter chips and segmented controls; switches; selects; text fields; panels and modals; hero portrait and card-frame bases; status markers; and scroll treatment.

Pressed/toggled controls change border geometry and, where relevant, show a check icon, so selected state is not conveyed by colour alone. Visible art may remain compact, but the helper enforces a minimum 64×64 design-space touch target.

`scenes/common/ui_kit_preview.tscn` is a non-product validation scene used to ensure every primitive instantiates and imports cleanly before later screens adopt the system.

## Import policy

Source fonts and SVG files are Git-tracked. Godot-generated `.import` sidecars are tracked after clean Godot 4.7.2 import. The `.godot/` imported cache remains ignored and must never be copied between checkouts.

No Stage 7A resource uses an absolute machine path.
