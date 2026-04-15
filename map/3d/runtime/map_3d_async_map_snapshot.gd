extends RefCounted


var effective_typ: PackedByteArray = PackedByteArray()
var blg: PackedByteArray = PackedByteArray()
var w := 0
var h := 0
var level_set := 0
var game_data_type := "original"


func set_snapshot(
		new_effective_typ: PackedByteArray,
		new_blg: PackedByteArray,
		new_w: int,
		new_h: int,
		new_level_set: int,
		new_game_data_type: String
	) -> void:
	effective_typ = new_effective_typ
	blg = new_blg
	w = new_w
	h = new_h
	level_set = new_level_set
	game_data_type = new_game_data_type


func clear() -> void:
	effective_typ = PackedByteArray()
	blg = PackedByteArray()
	w = 0
	h = 0
	level_set = 0
	game_data_type = "original"
