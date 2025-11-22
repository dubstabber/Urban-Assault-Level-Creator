extends Window

@onready var sky_picker_window: Window = %SkyPickerWindow
@onready var level_set_option_button: OptionButton = %LevelSetOptionButton
@onready var movies_option_button: OptionButton = %MoviesOptionButton
@onready var event_loop_option_button: OptionButton = %EventLoopOptionButton
@onready var sky_option_button: OptionButton = %SkyOptionButton
@onready var sky_texture: TextureRect = %SkyTexture
@onready var music_option_button: OptionButton = %MusicOptionButton
@onready var music_button: Button = %MusicButton
@onready var music_player: AudioStreamPlayer = %MusicPlayer
@onready var min_break_line_edit: LineEdit = %MinBreakLineEdit
@onready var max_break_line_edit: LineEdit = %MaxBreakLineEdit


func _on_about_to_popup() -> void:
	level_set_option_button.select(level_set_option_button.get_item_index(CurrentMapData.level_set))
	var movie_file: String = Preloads.movies_db.find_key(CurrentMapData.movie) if Preloads.movies_db.find_key(CurrentMapData.movie) else ""
	var movie_index := 0
	if not movie_file.is_empty():
		movie_index = get_option_index_by_text(movies_option_button, movie_file)
	movies_option_button.select(movie_index)
	event_loop_option_button.selected = CurrentMapData.event_loop
	var sky_index = get_option_index_by_text(sky_option_button, CurrentMapData.sky)
	sky_option_button.select(sky_index)
	sky_texture.texture = Preloads.get_sky(CurrentMapData.sky)
	music_option_button.selected = music_option_button.get_item_index(CurrentMapData.music)
	min_break_line_edit.text = str(CurrentMapData.min_break)
	max_break_line_edit.text = str(CurrentMapData.max_break)


func _on_save_button_pressed() -> void:
	CurrentMapData.level_set = level_set_option_button.get_selected_id()
	CurrentMapData.movie = Preloads.movies_db[movies_option_button.get_item_text(movies_option_button.selected)]
	CurrentMapData.event_loop = event_loop_option_button.selected
	CurrentMapData.sky = sky_option_button.get_item_text(sky_option_button.selected)
	CurrentMapData.music = music_option_button.get_item_id(music_option_button.selected)
	CurrentMapData.min_break = int(min_break_line_edit.text)
	CurrentMapData.max_break = int(max_break_line_edit.text)
	hide()
	music_button.text = "Play"
	music_button.button_pressed = false
	music_player.stop()
	EventSystem.map_updated.emit()


func _on_cancel_button_pressed() -> void:
	hide()
	music_button.text = "Play"
	music_button.button_pressed = false
	music_player.stop()


func get_option_index_by_text(option_button: OptionButton, text: String) -> int:
	for i in range(option_button.item_count):
		if option_button.get_item_text(i) == text:
			return i
	return -1


func _on_sky_option_button_item_selected(index: int) -> void:
	var sky_text = sky_option_button.get_item_text(index)
	sky_texture.texture = Preloads.get_sky(sky_text)


func _on_music_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		var music_id = music_option_button.get_item_id(music_option_button.selected)
		if music_id > 1:
			music_button.text = "Stop"
			music_player.stream = Preloads.musics[music_id]
			music_player.play()
		else:
			music_button.button_pressed = false
	else:
		music_button.text = "Play"
		music_player.stop()


func _on_pick_sky_button_pressed() -> void:
	sky_picker_window.popup()


func _on_sky_picker_window_sky_selected(sky_name: String) -> void:
	var index = get_option_index_by_text(sky_option_button, sky_name)
	sky_option_button.select(index)
	sky_texture.texture = Preloads.skies[sky_name]
