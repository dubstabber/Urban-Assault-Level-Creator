extends RefCounted

# Verifies ContextMenuPlacement keeps a context menu (and room for its widest
# first-level submenu) inside the usable screen, so submenus open beside the
# menu instead of flipping on top of it near a screen edge.

const Placement := preload("res://map/context_menu_placement.gd")

var _errors: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("[ContextMenuPlacementTest] " + msg)
		_errors.append(msg)


func _make_submenu(parent: PopupMenu, sub_name: String, width: int) -> PopupMenu:
	var sub := PopupMenu.new()
	sub.name = sub_name
	sub.min_size = Vector2i(width, 40)
	sub.add_item("Item")
	parent.add_child(sub)
	parent.add_submenu_item("Open %s >" % sub_name, sub_name)
	return sub


# Builds a menu whose submenu nesting widths follow `submenu_widths` (one entry
# per level, deepest last). [] -> no submenus.
func _make_menu(menu_w: int, submenu_widths: Array) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.min_size = Vector2i(menu_w, 40)
	menu.add_item("Item")
	var parent := menu
	for i in submenu_widths.size():
		parent = _make_submenu(parent, "sub%d" % i, int(submenu_widths[i]))
	return menu


func run() -> int:
	_errors.clear()
	var usable := Rect2i(0, 0, 1920, 1080)

	# 1) Near the bottom-right corner: the menu must be shifted left so the
	#    submenu still fits to its right (no flip), and stay on screen.
	var menu := _make_menu(200, [400])
	var reserve := Placement.submenu_chain_width(menu)
	_check(reserve >= 400, "submenu_chain_width should reflect the submenu min width, got %d" % reserve)
	var pos := Placement.clamped_position(menu, Vector2i(1900, 1060), usable)
	var menu_w: int = menu.size.x
	var menu_h: int = menu.size.y
	_check(pos.x + menu_w + reserve <= usable.position.x + usable.size.x,
		"submenu would still overflow the right edge: pos.x=%d menu_w=%d reserve=%d" % [pos.x, menu_w, reserve])
	_check(pos.x >= usable.position.x, "menu pushed off the left edge: %d" % pos.x)
	_check(pos.y >= usable.position.y and pos.y + menu_h <= usable.position.y + usable.size.y,
		"menu not kept within the vertical bounds: pos.y=%d menu_h=%d" % [pos.y, menu_h])
	menu.free()

	# 2) Submenus nested inside submenus: the whole chain width must be reserved,
	#    so a sub-submenu near the edge doesn't flip onto its parent either.
	var nested := _make_menu(200, [300, 250])  # main | sub0(300) | sub1(250)
	var nested_reserve := Placement.submenu_chain_width(nested)
	_check(nested_reserve >= 300 + 250,
		"nested chain width must sum the whole chain, got %d (want >= 550)" % nested_reserve)
	var npos := Placement.clamped_position(nested, Vector2i(1900, 1060), usable)
	_check(npos.x + nested.size.x + nested_reserve <= usable.position.x + usable.size.x,
		"deepest submenu chain would overflow: pos.x=%d menu_w=%d reserve=%d" % [npos.x, nested.size.x, nested_reserve])
	nested.free()

	# 3) A click with plenty of room must be left untouched (no needless shift).
	var menu2 := _make_menu(200, [400])
	var here := Vector2i(500, 300)
	var pos2 := Placement.clamped_position(menu2, here, usable)
	_check(pos2 == here, "menu away from edges should not move: got %s want %s" % [pos2, here])
	menu2.free()

	# 4) A menu without submenus reserves nothing but is still kept on screen.
	var menu3 := _make_menu(200, [])
	_check(Placement.submenu_chain_width(menu3) == 0, "menu without submenus should reserve 0")
	var pos3 := Placement.clamped_position(menu3, Vector2i(1915, 500), usable)
	_check(pos3.x + menu3.size.x <= usable.position.x + usable.size.x, "submenu-less menu ran off the right edge")
	menu3.free()

	if _errors.is_empty():
		print("[ContextMenuPlacementTest] OK")
	return _errors.size()
