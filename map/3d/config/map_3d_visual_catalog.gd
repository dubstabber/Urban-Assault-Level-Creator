extends RefCounted

const HOST_STATION_BASE_NAMES := {
	56: "VP_ROBO",
	57: "VP_KROBO",
	58: "VP_BRGRO",
	59: "VP_GIGNT",
	60: "VP_TAERO",
	61: "VP_SULG1",
	62: "VP_BSECT",
	132: "VP_TRAIN",
	176: "VP_GIGNT",
	177: "VP_KROBO",
	178: "VP_TAERO",
}

const HOST_STATION_VISIBLE_GUN_BASE_NAMES := {
	90: "VP_MFLAK",
	91: "VP_MFLAK",
	92: "VP_MFLAK",
	93: "VP_FLAK2",
	94: "VP_FLAK2",
	95: "VP_FLAK2",
}

const HOST_STATION_GUN_ATTACHMENTS := {
	56: [
		{"gun_type": 90, "ua_offset": Vector3(0.0, -200.0, 55.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 91, "ua_offset": Vector3(0.0, -180.0, -80.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
		{"gun_type": 92, "ua_offset": Vector3(0.0, -390.0, 0.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 93, "ua_offset": Vector3(0.0, 150.0, 0.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
	],
	62: [
		{"gun_type": 95, "ua_offset": Vector3(0.0, -150.0, 375.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 94, "ua_offset": Vector3(0.0, -120.0, -380.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
}

const TECH_UPGRADE_EDITOR_TYP_OVERRIDES := {
	4: 100,
	7: 73,
	15: 104,
	16: 103,
	50: 102,
	51: 101,
	60: 106,
	61: 113,
	65: 110,
}
