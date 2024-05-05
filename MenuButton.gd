extends MenuButton

var menupopup: PopupMenu = self.get_popup()

func _ready():
	menupopup.add_item("my new item")

