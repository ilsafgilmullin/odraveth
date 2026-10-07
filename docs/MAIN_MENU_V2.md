# Stage 7B — Main Menu V2

Stage 7B changes presentation and routing shell only. It does not alter MatchEngine, cards, hero powers, AI, DeckValidator, BattleSession, save schema, Progress, or Settings semantics.

## Composition

- Guardian Terrace of the Citadel of Nulmeris is represented by a lightweight procedural composition placeholder.
- The Guardian occupies the left composition region and is a deliberately faceless silhouette placeholder.
- The Guardian Staff is represented only by the approved three-ring composition hook.
- The right region contains the typographic ODRAVETH placeholder, navigation, and tertiary player setup status.

The Guardian, background and wordmark are **not final art/assets**. Their nodes and proportions are production slots intended to be replaced without changing routing or responsive structure.

## Alive V1

The backdrop uses a small fixed number of CanvasItem draw calls for clouds, distant towers, waterfalls, terrace stone and architectural arcs. Guardian motion is limited to subtle procedural breathing/staff drift. No particles, full-screen shader, Tween loop, texture animation, audio, or runtime node creation is used.

## Setup status

The menu reads the current hero from `AppState.profile`, hero/faction presentation from `HeroCatalog` / `SetupUi`, saved decks from `PlayerSetupData.decks_for()`, and readiness from `UserDeck.is_ready()`.

The primary action uses only `PlayerSetupData.selected_deck()`:
- valid selected saved deck -> Prebattle;
- otherwise -> Deck Builder.

No technical player deck/config is generated.

## History

`Routes.HISTORY` points to a minimal Visual Alpha shell titled **КНИГА НУЛМЕРИСА**. Library content remains deferred; Stage 7B does not invent book sections or author credit.
