extends RefCounted

const ViewController := preload("res://map/3d/controllers/map_3d_view_controller.gd")

var _renderer_node = null
var _context = null
var _scene = null
var _mouselook := false
var _yaw := 0.0
var _pitch := -0.6
var _move_speed := 1200.0
var _sprint_mult := 2.0
var _look_sens := 0.0025
var _framed := false


func bind(renderer, context_port, scene_port) -> void:
	_renderer_node = renderer
	_context = context_port
	_scene = scene_port


func process_frame() -> void:
	if not _mouselook and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func physics_process(delta: float) -> void:
	if not _scene.is_visible_in_tree():
		return
	var move := Vector3.ZERO
	var camera: Camera3D = _scene.camera()
	if camera == null or not is_instance_valid(camera):
		return
	var cam_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = -cam_basis.z.normalized()
	var right: Vector3 = cam_basis.x.normalized()
	if Input.is_physical_key_pressed(KEY_W):
		move += forward
	if Input.is_physical_key_pressed(KEY_S):
		move -= forward
	if Input.is_physical_key_pressed(KEY_D):
		move += right
	if Input.is_physical_key_pressed(KEY_A):
		move -= right
	if Input.is_physical_key_pressed(KEY_E):
		move += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		move -= Vector3.UP
	if move.length() > 0.0:
		move = move.normalized()
	var speed := _move_speed * (_sprint_mult if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	camera.global_translate(move * speed * delta)
	_scene.update_geometry_distance_culling_visibility()


func unhandled_input(event: InputEvent) -> void:
	if not _scene.is_visible_in_tree():
		return
	var camera: Camera3D = _scene.camera()
	if camera == null or not is_instance_valid(camera):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouselook = mb.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _mouselook else Input.MOUSE_MODE_VISIBLE)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera.translate_object_local(Vector3(0, 0, -wheel_step()))
			_scene.update_geometry_distance_culling_visibility()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera.translate_object_local(Vector3(0, 0, wheel_step()))
			_scene.update_geometry_distance_culling_visibility()
	elif event is InputEventMouseMotion and _mouselook:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * _look_sens
		_pitch = clampf(_pitch - mm.relative.y * _look_sens, deg_to_rad(-85.0), deg_to_rad(85.0))
		update_camera_rotation()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.keycode == KEY_F9:
			_renderer_node._debug_shader_mode = (_renderer_node._debug_shader_mode + 1) % 3
			_renderer_node._apply_debug_mode_to_existing_materials()
			_scene.bump_3d_viewport_rendering()


func wheel_step() -> float:
	return ViewController.wheel_step(_context.current_map_data(), _renderer_node.SECTOR_SIZE)


func update_camera_rotation() -> void:
	var camera: Camera3D = _scene.camera()
	if camera == null or not is_instance_valid(camera):
		return
	ViewController.apply_camera_rotation(camera, _yaw, _pitch)


func frame_if_needed() -> void:
	if _framed:
		return
	var camera: Camera3D = _scene.camera()
	if camera == null or not is_instance_valid(camera):
		return
	var frame_result := ViewController.frame_camera_to_map(camera, _context.current_map_data(), _renderer_node.SECTOR_SIZE, _renderer_node.HEIGHT_SCALE)
	if frame_result.is_empty():
		return
	_pitch = float(frame_result.get("pitch", _pitch))
	_yaw = float(frame_result.get("yaw", _yaw))
	_framed = bool(frame_result.get("framed", false))
	_scene.update_geometry_distance_culling_visibility()


func focus_sector(sector_sx: int, sector_sy: int) -> void:
	var camera: Camera3D = _scene.camera()
	if camera == null or not is_instance_valid(camera):
		return
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	var frame_result := ViewController.frame_camera_to_sector(camera, cmd, sector_sx, sector_sy, _renderer_node.SECTOR_SIZE, _renderer_node.HEIGHT_SCALE)
	if frame_result.is_empty():
		return
	_pitch = float(frame_result.get("pitch", _pitch))
	_yaw = float(frame_result.get("yaw", _yaw))
	_framed = bool(frame_result.get("framed", false))
	_scene.update_geometry_distance_culling_visibility()
	if _context.preview_refresh_active():
		_scene.bump_3d_viewport_rendering()


func set_framed(value: bool) -> void:
	_framed = value


func get_pitch() -> float:
	return _pitch


func get_yaw() -> float:
	return _yaw
