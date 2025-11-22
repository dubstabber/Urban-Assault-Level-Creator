extends AcceptDialog


func _ready() -> void:
	EventSystem.load_enemy_settings_failed.connect(func(path: String):
		dialog_text = "File '%s' could not be loaded" % path
		_show_modal_with_focus.call_deferred()
		)
	EventSystem.save_enemy_settings_failed.connect(func(path: String):
		dialog_text = "File '%s' could not be saved" % path
		_show_modal_with_focus.call_deferred()
		)


func _show_modal_with_focus() -> void:
	popup()
	# Small delay to ensure window is properly initialized before grabbing focus
	await get_tree().process_frame
	# Find first focusable child and grab focus
	var focusable = _find_focusable_child(self)
	if focusable:
		focusable.grab_focus()
	else:
		grab_focus()


func _find_focusable_child(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node as Control
	for child in node.get_children():
		var result = _find_focusable_child(child)
		if result:
			return result
	return null
