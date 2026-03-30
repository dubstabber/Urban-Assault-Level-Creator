extends Node

var _busy: bool = false

func request_open_map(path: String) -> void:
	call_deferred("_deferred_run_open_map", path)


func _deferred_run_open_map(path: String) -> void:
	if path.is_empty():
		return
	if _busy:
		return
	_busy = true
	await _run_open_map(path)
	_busy = false


func _run_open_map(path: String) -> void:
	EventSystem.map_load_started.emit()
	await get_tree().process_frame
	CurrentMapData.close_map()
	CurrentMapData.map_path = path
	var opener := SingleplayerOpener.new()
	await opener.load_level_async(self)
	await get_tree().process_frame
	EventSystem.map_load_finished.emit()
