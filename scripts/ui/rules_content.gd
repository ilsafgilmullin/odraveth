class_name RulesContent
extends VBoxContainer
## Player-facing summary of approved rules from docs/PRODUCT_BASELINE.md.
## This view explains existing MatchEngine behaviour and never defines new rules.

const SECTIONS := [
	["ЦЕЛЬ МАТЧА", "Снизьте здоровье героя соперника с 30 до 0. Если оба героя погибают одновременно, матч заканчивается ничьей."],
	["КОЛОДА И СТАРТОВАЯ РУКА", "Колода содержит ровно 30 карт: карты фракции вашего героя и нейтральные. Первый игрок начинает с 3 карт, второй — с 4 и получает Осколок импульса. Перед боем можно один раз заменить любые карты стартовой руки."],
	["ХОД И ЭНЕРГИЯ", "В первый свой ход у вас 1 энергия. В начале каждого следующего хода максимум растёт на 1, до 10, а энергия полностью восстанавливается. В свой ход можно разыгрывать карты, атаковать, использовать способность героя и завершить ход."],
	["КАРТЫ", "Существа выходят на поле и обычно не атакуют в ход появления. Заклинания выполняют свой текст сразу. Одновременно активен не более чем один артефакт. На вашей стороне поля может быть до 7 существ, в руке — до 10 карт."],
	["АТАКА И БРОНЯ", "При бое существ урон наносится одновременно. Герой не наносит ответный урон. Броня существа принимает урон первой; остаток уменьшает здоровье."],
	["СПОСОБНОСТЬ ГЕРОЯ", "Способность героя стоит 2 энергии и используется не более одного раза за ваш ход. Если способность требует цель, без подходящей цели она недоступна."],
	["ОСКОЛОК ИМПУЛЬСА", "Второй игрок может один раз за матч получить +1 временную энергию до конца текущего хода. Постоянный максимум энергии от этого не меняется."],
	["ПУСТАЯ КОЛОДА", "Неудачный добор из пустой колоды вызывает Разлом: герой получает 1 урон, затем 2, 3 и так далее при каждом следующем неудачном доборе."],
]


func _init() -> void:
	name = "RulesContent"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", VisualTokens.SPACE_4)
	for item: Array in SECTIONS:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", VisualTokens.SPACE_1)
		add_child(section)
		var heading := UiKit.make_display_label(item[0])
		heading.add_theme_font_size_override("font_size", 30)
		section.add_child(heading)
		var body := Label.new()
		body.text = item[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 24)
		body.add_theme_color_override("font_color", VisualTokens.COLOR_INK)
		section.add_child(body)
