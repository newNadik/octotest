extends Control


const GAME_SCENE_PATH := "res://scenes/main.tscn"

@onready var play_button: Button = $CenterContainer/MenuPanel/MenuMargin/MenuButtons/PlayButton
@onready var quit_button: Button = $CenterContainer/MenuPanel/MenuMargin/MenuButtons/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_quit_pressed()


func _on_play_pressed() -> void:
	var error := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		push_error("Failed to load game scene: %s" % GAME_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
