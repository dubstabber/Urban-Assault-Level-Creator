extends SceneTree

# Manual runtime smoke test (NOT auto-discovered: filename lacks "test_" prefix).
# Regression guard for the bug where changing a squad's faction in the properties
# panel did not update its colour/texture on the 2D map until another redraw.
# Verifies that Squad.change_faction() repaints the sprite AND re-schedules the
# on-demand 2D SubViewport (via the unit's visual_changed signal). Run:
#   ./Godot ... --headless --path . --script res://tests/_smoke_faction_refresh.gd

var _inst: Control
var _map: Node2D
var _ev: Node
var _cmd: Node
var _es: Node
var _pl: Node


func _init() -> void:
	call_deferred("_setup")


func _vp() -> SubViewport:
	return _inst.get_node("SubViewportMapContainer/SubViewport")


func _setup() -> void:
	_ev = root.get_node_or_null("/root/EventSystem")
	_cmd = root.get_node_or_null("/root/CurrentMapData")
	_es = root.get_node_or_null("/root/EditorState")
	_pl = root.get_node_or_null("/root/Preloads")
	if _ev == null or _cmd == null or _es == null or _pl == null:
		print("PROBE_SKIP autoloads unavailable")
		quit(0)
		return

	_inst = load("res://map/map_container.tscn").instantiate()
	root.add_child(_inst)
	_inst.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inst.size = Vector2(1000, 700)
	_map = _inst.get_node("%Map")

	# Minimal valid map.
	var w := 8
	var h := 8
	_cmd.horizontal_sectors = w
	_cmd.vertical_sectors = h
	var playable := w * h
	_cmd.typ_map = PackedByteArray(); _cmd.typ_map.resize(playable)
	_cmd.own_map = PackedByteArray(); _cmd.own_map.resize(playable)
	_cmd.blg_map = PackedByteArray(); _cmd.blg_map.resize(playable)
	_cmd.hgt_map = PackedByteArray(); _cmd.hgt_map.resize((w + 2) * (h + 2))
	_ev.map_created.emit()

	# Find a valid squad vehicle id from the loaded UA data.
	var vehicle_id := -1
	var hoststations = _pl.ua_data.data["original"].hoststations
	for hs_key in hoststations:
		for squad_def in hoststations[hs_key].units:
			vehicle_id = int(squad_def.id)
			break
		if vehicle_id != -1:
			break
	if vehicle_id == -1:
		print("PROBE_SKIP no squad vehicle id found")
		quit(0)
		return

	var squad = _pl.SQUAD.instantiate()
	_map.get_node("Squads").add_child(squad)
	var visual_count := [0]
	squad.visual_changed.connect(func(): visual_count[0] += 1)
	squad.create(1, vehicle_id)  # faction 1 (blue)
	await process_frame
	var tex_before = squad.texture

	# Clear the (dummy-renderer-sticky) UPDATE_ONCE, then change faction.
	_vp().render_target_update_mode = SubViewport.UPDATE_DISABLED
	var count_before: int = visual_count[0]
	squad.change_faction(6)  # faction 6 (red) -> different texture
	await process_frame

	var tex_after = squad.texture
	var mode_after: int = _vp().render_target_update_mode
	var emitted: bool = visual_count[0] > count_before
	var tex_changed: bool = tex_before != tex_after and tex_after != null
	var rescheduled: bool = mode_after == SubViewport.UPDATE_ONCE

	print("PROBE faction-emits-visual_changed=%s" % emitted)
	print("PROBE texture-changed=%s (before=%s after=%s)" % [tex_changed, tex_before, tex_after])
	print("PROBE viewport-rescheduled=%s (mode=%d want=%d)" % [rescheduled, mode_after, SubViewport.UPDATE_ONCE])
	var ok := emitted and tex_changed and rescheduled
	print("PROBE RESULT %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
