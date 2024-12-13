extends Node

enum State {
	Select,
	TypMapDesign
}

var mode: State = State.Select:
	set(value):
		mode = value
		EventSystem.editor_mode_changed.emit()

var selected_typ_map: int
