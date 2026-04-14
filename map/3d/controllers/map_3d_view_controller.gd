extends RefCounted

const UA_NORMAL_VIZ_LIMIT := 1400.0
const UA_NORMAL_FADE_LENGTH := 600.0
const UA_VISIBILITY_FOG_COLOR := Color.BLACK
## Camera height above terrain reference when framing the map (new map / open / reframe).
const UA_FRAMED_CAMERA_HEIGHT_ABOVE_TERRAIN := 600.0


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
	var y_offset: float = UA_FRAMED_CAMERA_HEIGHT_ABOVE_TERRAIN
	# Orbit from map center using the framed yaw/pitch so we look toward the center (not straight down):
	# place eye at vertical offset y_offset while keeping camera forward = -basis.z.
	var forward := (-camera.global_transform.basis.z).normalized()
	var fy := forward.y
	if absf(fy) < 1e-3:
		fy = -1e-3
	var orbit_r: float = -y_offset / fy
	var eye := center - forward * orbit_r
	camera.global_position = eye
	var far_dist: float = max(dist * 4.0, 50000.0)
	camera.near = 0.1
	camera.far = min(far_dist, 1.0e7)
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


static func _height_at_playable_cell(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int, height_scale: float) -> float:
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or w <= 0 or h <= 0:
		return 0.0
	var bx := clampi(sx + 1, 0, bw - 1)
	var by := clampi(sy + 1, 0, bh - 1)
	return float(hgt[by * bw + bx]) * height_scale


static func frame_camera_to_sector(camera: Camera3D, current_map_data: Node, sector_sx: int, sector_sy: int, sector_size: float, height_scale: float) -> Dictionary:
	if camera == null or current_map_data == null:
		return {}
	var w: int = int(current_map_data.horizontal_sectors)
	var h: int = int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return {}
	var sx := clampi(sector_sx, 0, w - 1)
	var sy := clampi(sector_sy, 0, h - 1)
	var hgt: PackedByteArray = current_map_data.hgt_map
	var terrain_y := _height_at_playable_cell(hgt, w, h, sx, sy, height_scale)
	var center := Vector3((float(sx) + 1.5) * sector_size, terrain_y, (float(sy) + 1.5) * sector_size)
	var dist: float = maxf(sector_size * 12.0, float(max(w + 2, h + 2)) * sector_size * 0.25)
	var pitch := deg_to_rad(-35.0)
	var yaw := deg_to_rad(45.0)
	apply_camera_rotation(camera, yaw, pitch)
	var y_offset: float = UA_FRAMED_CAMERA_HEIGHT_ABOVE_TERRAIN
	var forward := (-camera.global_transform.basis.z).normalized()
	var fy := forward.y
	if absf(fy) < 1e-3:
		fy = -1e-3
	var orbit_r: float = -y_offset / fy
	var eye := center - forward * orbit_r
	camera.global_position = eye
	var far_dist: float = max(dist * 4.0, 50000.0)
	camera.near = 0.1
	camera.far = min(far_dist, 1.0e7)
	return {
		"framed": true,
		"pitch": pitch,
		"yaw": yaw,
		"center": center,
		"dist": dist,
		"y_offset": y_offset,
	}
