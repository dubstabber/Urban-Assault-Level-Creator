class_name BeamGate

var sec_x: int
var sec_y: int
## 1 with road, 2 without road
var type := 1
var key_sectors: Array[Vector2] = []
var target_level: Array[int] = []
var mb_status := false


func _init(x: int, y: int) -> void:
	sec_x = x
	sec_y = y
