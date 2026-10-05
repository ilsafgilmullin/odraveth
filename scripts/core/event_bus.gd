extends Node
## Global signal hub for decoupled, cross-system notifications (autoload "EventBus").
##
## Rules (see docs/ARCHITECTURE.md):
## - signals only: no state, no logic, no references to other autoloads;
## - fire-and-forget notifications, never request/response calls;
## - match runtime events belong to the future MatchEngine instance, not to this bus.

## Emitted by SceneRouter after the screen of [param route_id] became the current scene.
@warning_ignore("unused_signal")
signal route_changed(route_id: StringName)

## Emitted by AppState when the local save could not be read or written.
## [param message] is a technical description for logs, not a player-facing text.
@warning_ignore("unused_signal")
signal save_error(message: String)
