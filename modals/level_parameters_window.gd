extends Window

@onready var sky_picker_window: Window = %SkyPickerWindow


func _on_about_to_popup() -> void:
	%LevelSetOptionButton.select(%LevelSetOptionButton.get_item_index(CurrentMapData.level_set))
	var movie_file:String = Preloads.movies_db.find_key(CurrentMapData.movie) if Preloads.movies_db.find_key(CurrentMapData.movie) else ""
	var movie_index := 0
	if not movie_file.is_empty():
		movie_index = get_option_index_by_text(%MoviesOptionButton, movie_file)
	%MoviesOptionButton.select(movie_index)
	%EventLoopOptionButton.selected = CurrentMapData.event_loop
	var sky_index = get_option_index_by_text(%SkyOptionButton, CurrentMapData.sky)
	%SkyOptionButton.select(sky_index)
	%SkyTexture.texture = Preloads.skies[CurrentMapData.sky]
	%MusicOptionButton.selected = %MusicOptionButton.get_item_index(CurrentMapData.music)
	%MinBreakLineEdit.text = str(CurrentMapData.min_break)
	%MaxBreakLineEdit.text = str(CurrentMapData.max_break)


func _on_save_button_pressed() -> void:
	CurrentMapData.level_set = %LevelSetOptionButton.get_selected_id()
	CurrentMapData.movie = Preloads.movies_db[%MoviesOptionButton.get_item_text(%MoviesOptionButton.selected)]
	CurrentMapData.event_loop = %EventLoopOptionButton.selected
	CurrentMapData.sky = %SkyOptionButton.get_item_text(%SkyOptionButton.selected)
	CurrentMapData.music = %MusicOptionButton.get_item_id(%MusicOptionButton.selected)
	CurrentMapData.min_break = int(%MinBreakLineEdit.text)
	CurrentMapData.max_break = int(%MaxBreakLineEdit.text)
	hide()
	%MusicButton.text = "Play"
	%MusicButton.button_pressed = false
	%MusicPlayer.stop()
	EventSystem.map_updated.emit()


func _on_cancel_button_pressed() -> void:
	hide()
	%MusicButton.text = "Play"
	%MusicButton.button_pressed = false
	%MusicPlayer.stop()


func get_option_index_by_text(option_button: OptionButton, text: String) -> int:
	for i in range(option_button.item_count):
		if option_button.get_item_text(i) == text:
			return i
	return -1


func _on_sky_option_button_item_selected(index: int) -> void:
	var sky_text = %SkyOptionButton.get_item_text(index)
	%SkyTexture.texture = Preloads.skies[sky_text]


func _on_music_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var music_id = %MusicOptionButton.get_item_id(%MusicOptionButton.selected)
		if music_id > 1:
			%MusicButton.text = "Stop"
			%MusicPlayer.stream = Preloads.musics[music_id]
			%MusicPlayer.play()
		else:
			%MusicButton.button_pressed = false
	else:
		%MusicButton.text = "Play"
		%MusicPlayer.stop()


func _on_pick_sky_button_pressed() -> void:
	%SkyPickerWindow.popup()


func _on_sky_picker_window_sky_selected(sky_name: String) -> void:
	var index = get_option_index_by_text(%SkyOptionButton, sky_name)
	%SkyOptionButton.select(index)
	%SkyTexture.texture = Preloads.skies[sky_name]
