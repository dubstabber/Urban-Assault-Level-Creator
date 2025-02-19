extends Window

const level_builder_document_path = "res://resources/Levelbuilder_English.doc"


func _ready() -> void:
	%InformationList.select(0)
	%InformationList.item_selected.connect(func(index:int):
		for child in %InformationContainer.get_children():
			child.hide()
		%InformationContainer.get_child(index).show()
	)


func close() -> void:
	hide()
