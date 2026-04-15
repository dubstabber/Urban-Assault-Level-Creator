extends RefCounted

const CASE_NAMES := [
	"small_visible_flat",
	"medium_visible_varied",
	"target_visible_varied_34x32",
	"target_visible_dense_units_32x32",
	"large_visible_varied",
	"set6_ptcl_visible",
	"large_hidden_refresh_workflow",
]


static func all_case_names() -> Array:
	return CASE_NAMES.duplicate()


static func get_case(case_name: String) -> Dictionary:
	match case_name:
		"small_visible_flat":
			return _make_case(case_name, "8x8 visible baseline terrain build", 8, 8, 1, "flat", [0, 1, 2, 3], true, 1, false, {"case_elapsed_ms_max": 1000.0, "build_total_ms_max": 1000.0})
		"medium_visible_varied":
			return _make_case(case_name, "24x24 visible mixed-height terrain and slurp workload", 24, 24, 1, "rolling", [0, 1, 2, 3, 4, 5], true, 1, false, {"case_elapsed_ms_max": 3000.0, "build_total_ms_max": 3000.0})
		"target_visible_varied_34x32":
			return _make_case(case_name, "34x32 visible target-sized terrain and slurp workload", 34, 32, 1, "rolling", [0, 1, 2, 3, 4, 5], true, 1, false, {"case_elapsed_ms_max": 4500.0, "build_total_ms_max": 4500.0})
		"target_visible_dense_units_32x32":
			return _make_case(case_name, "32x32 visible dense squads and host stations for overlay-load profiling", 32, 32, 1, "rolling", [0, 1, 2, 3, 4, 5], true, 1, false, {"case_elapsed_ms_max": 12000.0, "build_total_ms_max": 12000.0}, _make_dense_unit_specs(32, 32))
		"large_visible_varied":
			return _make_case(case_name, "64x64 visible large-map terrain and overlay baseline", 64, 64, 1, "rolling", [0, 1, 2, 3, 4, 5], true, 1, false, {"case_elapsed_ms_max": 8000.0, "build_total_ms_max": 8000.0})
		"set6_ptcl_visible":
			return _make_case(case_name, "6x6 visible set6 PTCL-heavy authored overlay case", 6, 6, 6, "terraced", [234, 235], true, 1, false, {"case_elapsed_ms_max": 1500.0, "build_total_ms_max": 1500.0})
		"large_hidden_refresh_workflow":
			return _make_case(case_name, "64x64 hidden-preview update burst followed by reactivation", 64, 64, 1, "rolling", [0, 1, 2, 3, 4, 5], false, 6, true, {"hidden_burst_elapsed_ms_max": 50.0, "build_total_ms_max": 8000.0, "expect_pending_refresh_before_reactivate": true, "expect_no_build_before_reactivate": true, "expect_pending_refresh_after_run": false})
	return {}


static func apply_map_data(target: Node, map_data: Dictionary) -> bool:
	if target == null or map_data.is_empty():
		return false
	for key in ["horizontal_sectors", "vertical_sectors", "level_set", "hgt_map", "typ_map", "blg_map", "beam_gates", "tech_upgrades", "stoudson_bombs"]:
		target.set(key, map_data.get(key, target.get(key)))
	return true


static func _make_case(case_name: String, description: String, w: int, h: int, set_id: int, height_mode: String, typ_palette: Array, start_visible: bool, map_update_burst: int, reactivate_after_burst: bool, smoke_budgets: Dictionary, unit_specs: Dictionary = {}) -> Dictionary:
	var map_data := _make_map_data(w, h, set_id, height_mode, typ_palette)
	for key in unit_specs.keys():
		map_data[key] = unit_specs[key]
	return {
		"name": case_name,
		"description": description,
		"map_data": map_data,
		"workflow": {
			"start_visible": start_visible,
			"map_update_burst": map_update_burst,
			"reactivate_after_burst": reactivate_after_burst,
		},
		"smoke_budgets": smoke_budgets.duplicate(true),
	}


static func _make_map_data(w: int, h: int, set_id: int, height_mode: String, typ_palette: Array) -> Dictionary:
	var hgt := PackedByteArray()
	hgt.resize((w + 2) * (h + 2))
	for y in range(h + 2):
		for x in range(w + 2):
			hgt[y * (w + 2) + x] = clampi(_height_value(x, y, height_mode), 0, 255)
	var palette := typ_palette if not typ_palette.is_empty() else [0]
	var typ := PackedByteArray()
	typ.resize(w * h)
	for y in range(h):
		for x in range(w):
			typ[y * w + x] = clampi(int(palette[(x + y * 3) % palette.size()]), 0, 255)
	var blg := PackedByteArray()
	blg.resize(w * h)
	return {
		"horizontal_sectors": w,
		"vertical_sectors": h,
		"level_set": set_id,
		"hgt_map": hgt,
		"typ_map": typ,
		"blg_map": blg,
		"beam_gates": [],
		"tech_upgrades": [],
		"stoudson_bombs": [],
	}


static func _make_dense_unit_specs(w: int, h: int) -> Dictionary:
	var host_station_specs: Array = []
	var squad_specs: Array = []
	var host_id := 1000
	var squad_id := 2000
	for sy in range(0, h, 4):
		for sx in range(0, w, 4):
			host_station_specs.append({
				"vehicle": 56,
				"x": (float(sx) + 1.5) * 1200.0,
				"y": (float(sy) + 1.5) * 1200.0,
				"pos_y": -700.0,
				"id": host_id,
			})
			host_id += 1
	for sy in range(0, h, 2):
		for sx in range(0, w, 2):
			squad_specs.append({
				"vehicle": 1,
				"x": (float(sx) + 1.5) * 1200.0,
				"y": (float(sy) + 1.5) * 1200.0,
				"quantity": 4 if ((sx + sy) % 4 == 0) else 2,
				"id": squad_id,
			})
			squad_id += 1
	return {
		"host_station_specs": host_station_specs,
		"squad_specs": squad_specs,
	}


static func _height_value(x: int, y: int, height_mode: String) -> int:
	match height_mode:
		"flat":
			return 0
		"terraced":
			return ((x % 5) * 2 + (y % 4) * 3) % 30
		_:
			return (x * 11 + y * 7 + ((x * y) % 13)) % 24
