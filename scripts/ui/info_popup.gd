extends Control


signal closed

@export_multiline var popup_title := "Info"
@export_multiline var popup_body := ""

@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/TitleLabel
@onready var body_label: RichTextLabel = $CenterContainer/PanelContainer/VBoxContainer/MarginContainer/BodyLabel
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/PanelContainer/HBoxContainer/CloseButton


func _ready() -> void:
	title_label.text = tr(popup_title)
	body_label.text = tr(popup_body)
	close_button.pressed.connect(_on_close_pressed)
	close_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_close_pressed()


func _on_close_pressed() -> void:
	emit_signal("closed")
	queue_free()
