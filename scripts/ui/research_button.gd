extends Button


@onready var arrow_icon: Control = $ArrowIcon


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_refresh_visual_state)
	focus_entered.connect(_refresh_visual_state)
	focus_exited.connect(_refresh_visual_state)
	button_down.connect(_refresh_visual_state)
	button_up.connect(_refresh_visual_state)
	_refresh_visual_state()


func _on_mouse_entered() -> void:
	# Keep a single active/highlighted button by syncing hover target with focus.
	grab_focus()
	_refresh_visual_state()


func _refresh_visual_state() -> void:
	var highlighted := has_focus() or button_pressed
	arrow_icon.visible = highlighted
