class_name HistoryShell
extends Control
## Stage 7B route-safe shell only. Library/History content is deferred to its own stage.


func _ready() -> void:
	UiKit.apply_root_theme(self)
	UiKit.style_button(%BackButton, UiKit.ButtonRole.SECONDARY)
	var display_font := load(UiKit.DISPLAY_FONT_PATH) as Font
	if display_font != null:
		%HistoryTitle.add_theme_font_override("font", display_font)
	%BackButton.pressed.connect(_go_back)


func _go_back() -> void:
	if SceneRouter.can_go_back():
		SceneRouter.go_back()
	else:
		SceneRouter.reset_to(Routes.MAIN_MENU)
