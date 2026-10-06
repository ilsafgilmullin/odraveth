class_name PrebattleScreen
extends PlaceholderScreen
## Technical Stage 4 launch until actual deck selection/prebattle UX is approved.


func _build_content() -> void:
	set_message("Технический бой: временные колоды и противник для проверки игрового потока")
	add_action("Начать бой", _start_battle, "NextButton")
	add_action("В главное меню", SceneRouter.reset_to.bind(Routes.MAIN_MENU), "MainMenuButton")


func _start_battle() -> void:
	var config := BattleLaunchConfig.technical_dev_config(CardDatabase)
	SceneRouter.go_to(Routes.BATTLE, {BattleLaunchConfig.PARAM_KEY: config})
