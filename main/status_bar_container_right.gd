extends HBoxContainer

@export var warning_icon: CompressedTexture2D
@export var no_warning_icon: CompressedTexture2D
@onready var logs_button: Button = %LogsButton


func _ready() -> void:
	logs_button.icon = no_warning_icon
