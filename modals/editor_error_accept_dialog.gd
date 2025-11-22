extends AcceptDialog


func _ready() -> void:
	EventSystem.editor_fatal_error_occured.connect(func(error_type: String):
		dialog_text = 'There was an error opening the editor:\n'
		match error_type:
			"invalid_json": dialog_text += 'data.json is not a valid file'
			"no_hoststations": dialog_text += 'there is no hoststations entry in the data.json for "%s" data set' % EditorState.game_data_type
			_: dialog_text += 'unknown fatal error'
		
		_show_modal_with_focus.call_deferred()
		await visibility_changed
		get_tree().quit()
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
