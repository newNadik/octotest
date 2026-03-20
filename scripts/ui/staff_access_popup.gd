extends "res://scripts/ui/info_popup.gd"


@onready var bcrc_id_input: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/BcrcIdInput
@onready var password_input: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/PasswordInput
@onready var login_button: Button = $CenterContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/LoginButton
@onready var error_label: Label = $CenterContainer/PanelContainer/VBoxContainer/MarginContainer/VBoxContainer/HBoxContainer/ErrorLabel


func _ready() -> void:
	super._ready()
	bcrc_id_input.placeholder_text = tr("BCRC ID")
	password_input.placeholder_text = tr("Password")
	login_button.text = tr("Login")
	error_label.text = tr("Wrong ID or Password")
	error_label.visible = false
	login_button.pressed.connect(_on_login_pressed)
	bcrc_id_input.text_submitted.connect(_on_text_submitted)
	password_input.text_submitted.connect(_on_text_submitted)
	bcrc_id_input.grab_focus()


func _on_text_submitted(_new_text: String) -> void:
	_on_login_pressed()


func _on_login_pressed() -> void:
	error_label.text = tr("Wrong ID or Password")
	error_label.visible = true
