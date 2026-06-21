extends Node

## Works around a Linux/Wayland (KDE) windowing quirk: when a modal is shown
## with an automatic `initial_position` (e.g. centered), the compositor places
## the native window but never reports the chosen coordinates back to Godot, so
## the window's cached `position` stays stale (typically (0, 0)).
##
## OptionButton/MenuButton compute their drop-down's on-screen position from that
## cached window position (via Control.get_screen_rect()), so inside a non-embedded
## subwindow the list pops up at the wrong place — usually the top-left corner of
## the screen instead of underneath the button.
##
## The drop-down's position cannot be corrected once it has been shown (the
## compositor honours a native popup's position only at map time, not a later
## move), so we instead re-sync the host window's cached position from the
## display server on `button_down` — which fires just before show_popup() reads
## that cache. By the time a user clicks, the compositor has long settled, so the
## queried position is the real one.
##
## Windows works correctly without this; the no-ops below leave it untouched.

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Catch buttons that were already in the tree before this autoload connected.
	for node in get_tree().root.find_children("*", "Button", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if (node is OptionButton or node is MenuButton) and not node.has_meta(&"_popup_fix"):
		node.set_meta(&"_popup_fix", true)
		node.button_down.connect(_sync_host_window_position.bind(node))


func _sync_host_window_position(button: Control) -> void:
	var window := button.get_window()
	# Only native (non-embedded) subwindows are affected; the main window and any
	# embedded subwindows already position their popups correctly.
	if window == null or window == get_tree().root or window.is_embedding_subwindows():
		return
	window.position = DisplayServer.window_get_position(window.get_window_id())
