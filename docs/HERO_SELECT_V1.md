# Stage 7C — Hero Select V1

Stage 7C is presentation and setup-flow work only. Hero mechanics, DeckValidator, saved-deck schema and BattleSession are unchanged.

## Structure

- Header: **ВЫБОР ГЕРОЯ** with restrained subtitle and Back.
- Main area: four simultaneous `HeroSelectCard` controls in the order defined by `PlayerSetupData.HERO_IDS`.
- Lower area: one canonical selected-hero information panel containing identity, faction, hero power name, authoritative cost, full wrapped description, playstyle and explicit confirmation.

Full power copy is intentionally **not** repeated inside four portrait cards.

## Data authority

- Hero IDs, Russian names, power names and mechanic values: `HeroCatalog`.
- Hero power cost: `GameRules.HERO_ABILITY_COST`.
- Faction names: `SetupUi`.
- Hero/deck commit semantics: `PlayerSetupData.select_hero()` + `AppState.persist_profile()`.
- Stage 7C presentation-only metadata: playstyle labels, approved gender identity and restrained faction accent colours live in `HeroPresentation`.

Descriptions interpolate numeric mechanic values from `HeroCatalog`; Stage 7C does not create a second gameplay rule source.

## Selection semantics

Tap updates only `pending_hero` and the preview. It does not mutate the persisted profile.

**ПОДТВЕРДИТЬ** calls the existing `PlayerSetupData.select_hero()` path. Therefore a changed hero clears an incompatible selected deck ID while all saved deck records remain untouched. Back before confirmation leaves the profile unchanged.

## Selected state

Selection is not colour-only:

- explicit **✓ ВЫБРАН** marker;
- stronger/thicker selected frame;
- slight 0.8% geometric elevation/scale that remains inside the four-card spacing budget.

Faction hue remains a restrained secondary accent.

## Art status

**HERO ART = VISUAL ALPHA TEMPORARY ASSET.**

Stage 7 replaced the grey debug bust with an art-directed temporary portrait (`HeroPortraitPlaceholder`, `is_temporary_asset() == true`): arched Citadel niche, faction backlight, faction symbol and a rim-lit silhouette that preserves the approved presentation gender (Syrraveth explicitly `female`). No face, costume, weapon or equipment canon is invented; the visible card no longer shows developer words. Final Character V1 artwork replaces it without layout changes.

Faction symbols use the Visual Alpha marks from `NulmerisEmblems` (Ashravael broken blade + angular flame crown, Nerqathen segmented ring with empty core, Dumoryss displaced ring with central fracture, Khevaruun interlocking shield plates). They are Visual Alpha candidates, not approved final emblems.

## Responsive policy

The screen uses four simultaneous cards at 1600×900, 1920×1080 and 2400×1080. Width classes adjust card-row height, spacing and title size without hiding heroes or shrinking the canonical full-description body text below the Stage 7C mobile readability target.

The power description uses word wrapping, clipping disabled and a reserved minimum height to prevent the Stage 6 real-device description-clipping regression.


## Stage 7C verification

Checkpoint validation uses the official Godot 4.7.2 stable binary and requires:

- clean checkout with no existing `.godot/`;
- error-free import of Stage 7A typography/theme, Stage 7B Main Menu and Stage 7C Hero Select;
- runtime Hero Select tests at 1600×900, 1920×1080 and 2400×1080;
- all four hero IDs/names/factions visible simultaneously;
- semantic full-description wrapping with clipping disabled and reserved height;
- explicit non-colour selected affordance;
- preview-only taps and explicit confirmation persistence;
- hero/deck isolation and stored-deck preservation;
- UI Back and Android-style system Back without unconfirmed mutation;
- repeated entry/exit without duplicate card nodes or signal connections;
- clean re-import after deleting `.godot/`;
- one full project regression at the checkpoint.
