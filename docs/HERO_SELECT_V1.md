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

**HERO ART = PLACEHOLDER.**

All four portrait slots use the same neutral production placeholder geometry and consistent crop. No final face, costume, weapon or body details are invented. `HeroPortraitPlaceholder.presentation_gender` preserves the approved identity contract; in particular Syrraveth is explicitly `female`.

Faction symbols are also temporary: the card reserves a dedicated symbol slot with the neutral geometric mark **◇** and labels it as a temporary symbol slot via tooltip. Final faction emblems are a separate asset task.

## Responsive policy

The screen uses four simultaneous cards at 1600×900, 1920×1080 and 2400×1080. Width classes adjust card-row height, spacing and title size without hiding heroes or shrinking the canonical full-description body text below the Stage 7C mobile readability target.

The power description uses word wrapping, clipping disabled and a reserved minimum height to prevent the Stage 6 real-device description-clipping regression.
