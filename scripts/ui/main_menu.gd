extends Control
## Main menu with the Stage 5 approved setup routes (Q-14).


func _ready() -> void:
	var routes_by_button := {
		%CollectionButton: Routes.COLLECTION,
		%DecksButton: Routes.DECK_BUILDER,
		%HeroesButton: Routes.HERO_SELECT,
		%ProgressButton: Routes.PROGRESS,
		%SettingsButton: Routes.SETTINGS,
	}
	for button: Button in routes_by_button:
		button.pressed.connect(SceneRouter.go_to.bind(routes_by_button[button]))
	%PlayButton.pressed.connect(_play)


func _play() -> void:
	var route := Routes.PREBATTLE if PlayerSetupData.selected_deck(AppState.profile, CardDatabase) != null else Routes.DECK_BUILDER
	SceneRouter.go_to(route)
