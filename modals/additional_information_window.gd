extends Window

const LEVEL_BUILDER_DOCUMENT_PATH = "res://resources/Levelbuilder_English.doc"


func _ready() -> void:
	%InformationList.select(0)
	%InformationList.item_selected.connect(func(index:int):
		for child in %InformationContainer.get_children():
			child.hide()
		%InformationContainer.get_child(index).show()
	)
	


func close() -> void:
	hide()


func _on_level_builder_file_label_meta_clicked(meta: Variant) -> void:
	if meta == "level_builder_doc":
		var file = FileAccess.open(LEVEL_BUILDER_DOCUMENT_PATH, FileAccess.READ)
		if not file: 
			printerr("Failed to load embedded .doc file.")
			return
		var buffer = file.get_buffer(file.get_length())
		file.close()
		
		var temp_path = OS.get_cache_dir() + "/Levelbuilder_English.doc"
		var temp_file = FileAccess.open(temp_path, FileAccess.WRITE)
		if not temp_file: 
			printerr("Failed to write temporary file.")
			return
		temp_file.store_buffer(buffer)
		temp_file.close()
		
		OS.shell_open(temp_path)
