class_name BeamGate

var sec_x: int
var sec_y: int
var closed_bp := 25
var opened_bp := 26
var key_sectors: Array[Vector2i] = []
var target_levels: Array[int] = []
var mb_status := false


func _init(x: int, y: int) -> void:
	sec_x = x
	sec_y = y
