extends RefCounted
## Shared presentation checks for screen tests: user-visible text must not expose
## developer/placeholder vocabulary.

const DEVELOPER_WORDS: Array[String] = ["ВРЕМЕННО", "АРТ ·", "PLACEHOLDER", "TODO", "DEBUG", "QA ", "ТЕСТОВ"]


static func visible_texts(root: Node) -> PackedStringArray:
	var texts := PackedStringArray()
	_collect(root, texts)
	return texts


static func has_developer_words(root: Node) -> bool:
	for text_value: String in visible_texts(root):
		var upper := text_value.to_upper()
		for word: String in DEVELOPER_WORDS:
			if upper.contains(word):
				return true
	return false


static func _collect(node: Node, texts: PackedStringArray) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Label:
		texts.append((node as Label).text)
	elif node is Button:
		texts.append((node as Button).text)
	elif node is RichTextLabel:
		texts.append((node as RichTextLabel).get_parsed_text())
	for child: Node in node.get_children():
		_collect(child, texts)
