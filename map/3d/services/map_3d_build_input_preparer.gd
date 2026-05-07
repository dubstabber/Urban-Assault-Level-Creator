extends RefCounted

const EffectiveTypService := preload("res://map/3d/services/map_3d_effective_typ_service.gd")

var _context = null
var _async_map_snapshot = null
var _effective_typ_service = null


func bind(context_port, async_map_snapshot, effective_typ_service) -> void:
	_context = context_port
	_async_map_snapshot = async_map_snapshot
	_effective_typ_service = effective_typ_service


func prepare_current_map() -> Dictionary:
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		return {
			"valid": false,
			"missing_map": true,
			"invalid_input": false,
		}

	var w: int = int(current_map_data.horizontal_sectors)
	var h: int = int(current_map_data.vertical_sectors)
	var hgt: PackedByteArray = current_map_data.hgt_map
	var typ: PackedByteArray = current_map_data.typ_map
	var blg: PackedByteArray = current_map_data.blg_map
	var expected_hgt_size: int = (w + 2) * (h + 2)
	if w <= 0 or h <= 0 or hgt.size() != expected_hgt_size or typ.size() != w * h:
		return {
			"valid": false,
			"missing_map": false,
			"invalid_input": true,
		}

	var game_data_type: String = _context.current_game_data_type()
	var level_set: int = int(current_map_data.level_set)
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	_async_map_snapshot.blg = blg
	_async_map_snapshot.w = w
	_async_map_snapshot.h = h
	_async_map_snapshot.level_set = level_set
	_async_map_snapshot.game_data_type = game_data_type

	var typ_checksum: int = EffectiveTypService.checksum_packed_byte_array(typ)
	var blg_checksum: int = EffectiveTypService.checksum_packed_byte_array(blg)
	var effective_typ: PackedByteArray
	if _effective_typ_service.is_valid_cache(w, h, game_data_type, typ_checksum, blg_checksum):
		effective_typ = _effective_typ_service.get_effective_typ()
	else:
		effective_typ = _effective_typ_service.compute_effective_typ_for_map(current_map_data, w, h, typ, blg, game_data_type)
	_async_map_snapshot.effective_typ = effective_typ

	return {
		"valid": true,
		"missing_map": false,
		"invalid_input": false,
		"current_map_data": current_map_data,
		"w": w,
		"h": h,
		"hgt": hgt,
		"typ": typ,
		"blg": blg,
		"level_set": level_set,
		"game_data_type": game_data_type,
		"effective_typ": effective_typ,
		"preloads": _context.preloads(),
	}
