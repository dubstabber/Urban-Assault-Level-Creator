class_name StoudsonBomb

var sec_x: int
var sec_y: int
var inactive_bp := 35
var active_bp := 36
var trigger_bp := 37
var type := 1
var countdown := 614400
var key_sectors: Array[Vector2i] = []


func _init(x: int, y: int) -> void:
	sec_x = x
	sec_y = y
