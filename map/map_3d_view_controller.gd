extends RefCounted
class_name Map3DViewController

const UA_NORMAL_VIZ_LIMIT := 2500.0
const UA_NORMAL_FADE_LENGTH := 1000.0
const UA_VISIBILITY_FOG_COLOR := Color.BLACK


static func visibility_range_fade_start(viz_limit: float = UA_NORMAL_VIZ_LIMIT, fade_length: float = UA_NORMAL_FADE_LENGTH) -> float:
	return maxf(maxf(viz_limit, 0.0) - maxf(fade_length, 0.0), 0.0)


static func visibility_range_config(viz_limit: float = UA_NORMAL_VIZ_LIMIT, fade_length: float = UA_NORMAL_FADE_LENGTH) -> Dictionary:
	var clamped_viz_limit := maxf(viz_limit, 0.0)
	return {
		"fade_start": visibility_range_fade_start(clamped_viz_limit, fade_length),
		"fade_end": clamped_viz_limit,
	}


static func apply_visibility_range_to_environment(environment: Environment, enabled: bool, viz_limit: float = UA_NORMAL_VIZ_LIMIT, fade_length: float = UA_NORMAL_FADE_LENGTH) -> bool:
	if environment == null:
		return false
	var config := visibility_range_config(viz_limit, fade_length)
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = float(config["fade_start"])
	environment.fog_depth_end = float(config["fade_end"])
	environment.fog_depth_curve = 1.0
	environment.fog_density = 1.0
	environment.fog_light_color = UA_VISIBILITY_FOG_COLOR
	environment.fog_light_energy = 1.0
	environment.fog_aerial_perspective = 0.0
	environment.fog_height_density = 0.0
	environment.fog_sky_affect = 0.0
	environment.fog_sun_scatter = 0.0
	environment.fog_enabled = enabled
	return true


static func wheel_step(current_map_data: Node, sector_size: float) -> float:
	var max_dim: int = int(max(current_map_data.horizontal_sectors, current_map_data.vertical_sectors)) if current_map_data != null else 1
	return max(200.0, float(max_dim) * sector_size * 0.02)


static func apply_camera_rotation(camera: Camera3D, yaw: float, pitch: float) -> void:
	if camera == null:
		return
	var rot := Basis()
	rot = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	camera.global_transform.basis = rot.orthonormalized()


static func frame_camera_to_map(camera: Camera3D, current_map_data: Node, sector_size: float, height_scale: float) -> Dictionary:
	if camera == null or current_map_data == null:
		return {}
	var w: int = int(current_map_data.horizontal_sectors)
	var h: int = int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return {}
	var center := Vector3((1.0 + w * 0.5) * sector_size, 0.0, (1.0 + h * 0.5) * sector_size)
	var dist: float = float(max(w + 2, h + 2)) * sector_size * 1.6
	var hgt: PackedByteArray = current_map_data.hgt_map
	var mn: int = 255
	var mx: int = 0
	var sum: int = 0
	var count: int = hgt.size()
	for i in count:
		var v: int = int(hgt[i])
		sum += v
		if v < mn:
			mn = v
		if v > mx:
			mx = v
	var avg_h: float = float(sum) / float(count) if count > 0 else 0.0
	var terrain_base_y: float = float(mx) * height_scale
	center.y = terrain_base_y
	var pitch := deg_to_rad(-35.0)
	var yaw := deg_to_rad(45.0)
	apply_camera_rotation(camera, yaw, pitch)
	var y_offset: float = max(dist * 0.35, 300.0)
	var desired_pos := Vector3(center.x, terrain_base_y + y_offset, center.z)
	# When eye shares X/Z with target, view axis is parallel to Vector3.UP and look_at's up is degenerate.
	var eye := desired_pos
	var fwd := center - eye
	if Vector2(fwd.x, fwd.z).length_squared() < 1e-8:
		eye.x += 1.0
	camera.global_transform.origin = eye
	var far_dist: float = max(dist * 4.0, 50000.0)
	camera.near = 0.1
	camera.far = min(far_dist, 1.0e7)
	camera.look_at(center, Vector3.UP)
	return {
		"framed": true,
		"pitch": pitch,
		"yaw": yaw,
		"center": center,
		"dist": dist,
		"y_offset": y_offset,
		"min_h": mn,
		"max_h": mx,
		"avg_h": avg_h,
	}
