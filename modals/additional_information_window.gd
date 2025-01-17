extends Window


func _ready() -> void:
	%InformationList.item_selected.connect(func(index:int):
		for child in %InformationContainer.get_children():
			child.hide()
		%InformationContainer.get_child(index).show()
	)


func close() -> void:
	hide()
