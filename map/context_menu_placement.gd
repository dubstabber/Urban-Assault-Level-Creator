## Places a context PopupMenu so its nested submenus don't open on top of it.
##
## Preloaded by path (no class_name) so it resolves in headless/CI runs where the
## global class cache isn't regenerated.
##
## Godot flips a submenu to the left (over its parent menu) when it would
## otherwise exceed the screen's right edge. Such an overlapping native submenu
## mishandles hover on Linux/Wayland — moving onto it lands in the parent menu's
## auto-hide area, so the submenu closes instead of letting you pick an item.
##
## A whole submenu chain (menu | submenu | sub-submenu | ...) stacks to the right,
## so we reserve room for the widest such chain: if the menu is near the right
## edge we shift it left until even the deepest chain fits beside it. The menu is
## also kept fully inside the usable screen.


## `desired` and `usable` are in the same (screen) coordinate space the menu is
## popped up in. Returns the clamped top-left for `menu`.
static func clamped_position(menu: PopupMenu, desired: Vector2i, usable: Rect2i) -> Vector2i:
	menu.reset_size()
	var menu_size: Vector2i = menu.size
	var reserve := submenu_chain_width(menu)
	var pos := desired
	# Leave menu_width + deepest submenu chain of room before the right edge.
	var max_x := usable.position.x + usable.size.x - menu_size.x - reserve
	pos.x = clampi(pos.x, usable.position.x, maxi(usable.position.x, max_x))
	var max_y := usable.position.y + usable.size.y - menu_size.y
	pos.y = clampi(pos.y, usable.position.y, maxi(usable.position.y, max_y))
	return pos


## Horizontal room the menu's submenus need to its right: the widest root-to-leaf
## chain of nested submenu widths (recurses into submenus-of-submenus). 0 if none.
static func submenu_chain_width(menu: PopupMenu) -> int:
	var widest := 0
	for child in menu.get_children():
		if child is PopupMenu:
			var submenu := child as PopupMenu
			submenu.reset_size()
			widest = maxi(widest, submenu.size.x + submenu_chain_width(submenu))
	return widest
