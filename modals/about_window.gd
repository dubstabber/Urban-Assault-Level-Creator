extends Window


@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	var version = ProjectSettings.get_setting("application/config/version", "1.0.0")
	version_label.text = "Version %s" % version


func close() -> void:
	hide()
