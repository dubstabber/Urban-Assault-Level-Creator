@tool
extends HBoxContainer

@export var key_text: String
@export var value_text: String
@export var font_size := 16

@onready var key_label: Label = $KeyLabel
@onready var value_label: Label = $ValueLabel


func _ready() -> void:
	key_label.text = key_text
	key_label["theme_override_font_sizes/font_size"] = font_size
	value_label.text = value_text
	value_label["theme_override_font_sizes/font_size"] = font_size
