extends Control
## Boot screen: initialises app-level services, then opens the main menu.
## Order: AppState (local save) -> CardDatabase (static data) -> main menu.


func _ready() -> void:
	# Deferred so the boot screen is fully in the tree before navigating away.
	_boot.call_deferred()


func _boot() -> void:
	AppState.initialize()
	var cards_error := CardDatabase.load_directory()
	if cards_error != OK:
		push_error("Boot: card data failed to load: %s." % error_string(cards_error))
	SceneRouter.reset_to(Routes.MAIN_MENU)
