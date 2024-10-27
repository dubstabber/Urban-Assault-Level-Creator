class_name TechUpgrade

var sec_x: int
var sec_y: int
var building_id := 4
var type := -1
var vehicles: Array[ModifyVehicle] = []
var weapons: Array[ModifyWeapon] = []
var buildings: Array[ModifyBuilding] = []
var mb_status := true


func _init(x: int, y: int) -> void:
	sec_x = x
	sec_y = y


class ModifyVehicle:
	var vehicle_id := 0
	var energy := 0
	var shield := 0
	var res_enabled := false
	var ghor_enabled := false
	var taer_enabled := false
	var myko_enabled := false
	var sulg_enabled := false
	var blacksect_enabled := false
	var training_enabled := false
	var radar := 0
	var weapon_num := 0
	var fire_x := 30.0
	var fire_y := 5.0
	var fire_z := 15.0


class ModifyWeapon:
	var weapon_id := 0
	var energy := 0 # damage
	var shot_time := 0
	var shot_time_user := 0


class ModifyBuilding:
	var building_id = 0
	var res_enabled := false
	var ghor_enabled := false
	var taer_enabled := false
	var myko_enabled := false
	var sulg_enabled := false
	var blacksect_enabled := false
	var training_enabled := false
