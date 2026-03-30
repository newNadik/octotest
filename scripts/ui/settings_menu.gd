extends Control


signal closed

const MAIN_MENU_SCENE_PATH := "res://scenes/main_menu.tscn"
const LOCALE_EN_GB := "en_GB"
const LOCALE_UK_UA := "uk_UA"
const LOCALES := [LOCALE_EN_GB, LOCALE_UK_UA]
const SLIDER_GRABBER_SIZE := 36
const SLIDER_GRABBER_RADIUS := 15.0
const COLOR_MID_BLUE := Color(0.007843138, 0.2627451, 0.43137255, 1.0) # 02436e

@export var is_overlay := false

@onready var back_button: BaseButton = $TopContainer/PanelContainer/MarginContainer/HBoxContainer/BackButton
@onready var title_label: Label = $TopContainer/PanelContainer/MarginContainer/HBoxContainer/Label
@onready var music_label: Label = $TopContainer/MainContainer/SettingsRows/MusicRow/MusicLabel
@onready var music_slider: HSlider = $TopContainer/MainContainer/SettingsRows/MusicRow/MusicSlider
@onready var music_value: Label = $TopContainer/MainContainer/SettingsRows/MusicRow/MusicValue
@onready var sounds_label: Label = $TopContainer/MainContainer/SettingsRows/SoundsRow/SoundsLabel
@onready var sounds_slider: HSlider = $TopContainer/MainContainer/SettingsRows/SoundsRow/SoundsSlider
@onready var sounds_value: Label = $TopContainer/MainContainer/SettingsRows/SoundsRow/SoundsValue
@onready var subtitles_label: Label = $TopContainer/MainContainer/SettingsRows/SubtitlesRow/SubtitlesLabel
@onready var subtitles_prev_button: Button = $TopContainer/MainContainer/SettingsRows/SubtitlesRow/SubtitlesSelector/SubtitlesPrevButton
@onready var subtitles_value_label: Label = $TopContainer/MainContainer/SettingsRows/SubtitlesRow/SubtitlesSelector/SubtitlesValueLabel
@onready var subtitles_next_button: Button = $TopContainer/MainContainer/SettingsRows/SubtitlesRow/SubtitlesSelector/SubtitlesNextButton
@onready var god_rays_label: Label = $TopContainer/MainContainer/SettingsRows/GodRaysRow/GodRaysLabel
@onready var god_rays_prev_button: Button = $TopContainer/MainContainer/SettingsRows/GodRaysRow/GodRaysSelector/GodRaysPrevButton
@onready var god_rays_value_label: Label = $TopContainer/MainContainer/SettingsRows/GodRaysRow/GodRaysSelector/GodRaysValueLabel
@onready var god_rays_next_button: Button = $TopContainer/MainContainer/SettingsRows/GodRaysRow/GodRaysSelector/GodRaysNextButton
@onready var language_label: Label = $TopContainer/MainContainer/SettingsRows/LanguageRow/LanguageLabel
@onready var language_prev_button: Button = $TopContainer/MainContainer/SettingsRows/LanguageRow/LanguageSelector/LanguagePrevButton
@onready var language_value_label: Label = $TopContainer/MainContainer/SettingsRows/LanguageRow/LanguageSelector/LanguageValueLabel
@onready var language_next_button: Button = $TopContainer/MainContainer/SettingsRows/LanguageRow/LanguageSelector/LanguageNextButton

var _is_updating_ui := false


func _ready() -> void:
	var running_paused := get_tree() != null and get_tree().paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED if (is_overlay and running_paused) else Node.PROCESS_MODE_INHERIT
	back_button.pressed.connect(_on_back_pressed)
	music_slider.value_changed.connect(_on_music_changed)
	sounds_slider.value_changed.connect(_on_sounds_changed)
	subtitles_prev_button.pressed.connect(_on_subtitles_cycle.bind(-1))
	subtitles_next_button.pressed.connect(_on_subtitles_cycle.bind(1))
	god_rays_prev_button.pressed.connect(_on_god_rays_cycle.bind(-1))
	god_rays_next_button.pressed.connect(_on_god_rays_cycle.bind(1))
	language_prev_button.pressed.connect(_on_language_cycle.bind(-1))
	language_next_button.pressed.connect(_on_language_cycle.bind(1))
	_apply_slider_grabber_icons()
	_load_settings_into_ui()
	_apply_localized_text()
	back_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	if is_overlay:
		emit_signal("closed")
		queue_free()
		return

	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error != OK:
		push_error("Failed to load main menu scene: %s" % MAIN_MENU_SCENE_PATH)


func _on_music_changed(value: float) -> void:
	if _is_updating_ui:
		return
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_music_volume"):
		settings.call("set_music_volume", value)
	_update_percent_label(music_value, value)


func _on_sounds_changed(value: float) -> void:
	if _is_updating_ui:
		return
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_sound_volume"):
		settings.call("set_sound_volume", value)
	_update_percent_label(sounds_value, value)


func _on_subtitles_cycle(_direction: int) -> void:
	var settings := _get_game_settings()
	var enabled := true
	if settings != null and settings.has_method("get_subtitles_enabled"):
		enabled = bool(settings.call("get_subtitles_enabled"))
	enabled = not enabled
	if settings != null and settings.has_method("set_subtitles_enabled"):
		settings.call("set_subtitles_enabled", enabled)
	_update_subtitles_value(enabled)


func _on_god_rays_cycle(_direction: int) -> void:
	var settings := _get_game_settings()
	var enabled := true
	if settings != null and settings.has_method("get_god_rays_enabled"):
		enabled = bool(settings.call("get_god_rays_enabled"))
	enabled = not enabled
	if settings != null and settings.has_method("set_god_rays_enabled"):
		settings.call("set_god_rays_enabled", enabled)
	_update_god_rays_value(enabled)


func _on_language_cycle(direction: int) -> void:
	var current_locale := _get_active_locale()
	var current_index := LOCALES.find(current_locale)
	if current_index < 0:
		current_index = 0
	var next_index := wrapi(current_index + direction, 0, LOCALES.size())
	var locale: String = str(LOCALES[next_index])
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_locale"):
		settings.call("set_locale", locale)
	else:
		TranslationServer.set_locale(locale)
	_apply_localized_text()


func _load_settings_into_ui() -> void:
	_is_updating_ui = true
	var settings := _get_game_settings()
	var music := 1.0
	var sounds := 1.0
	var subtitles_enabled := true
	var god_rays_enabled := true
	var locale: String = TranslationServer.get_locale()
	if settings != null:
		if settings.has_method("get_music_volume"):
			music = float(settings.call("get_music_volume"))
		if settings.has_method("get_sound_volume"):
			sounds = float(settings.call("get_sound_volume"))
		if settings.has_method("get_subtitles_enabled"):
			subtitles_enabled = bool(settings.call("get_subtitles_enabled"))
		if settings.has_method("get_god_rays_enabled"):
			god_rays_enabled = bool(settings.call("get_god_rays_enabled"))
		if settings.has_method("get_locale"):
			locale = str(settings.call("get_locale"))

	music_slider.value = music
	sounds_slider.value = sounds
	_update_percent_label(music_value, music)
	_update_percent_label(sounds_value, sounds)
	_update_subtitles_value(subtitles_enabled)
	_update_god_rays_value(god_rays_enabled)
	_update_language_value(locale)
	_is_updating_ui = false


func _apply_localized_text() -> void:
	title_label.text = tr("Settings")
	music_label.text = tr("Music")
	sounds_label.text = tr("Sound Effects")
	subtitles_label.text = tr("Subtitles")
	god_rays_label.text = tr("God Rays")
	language_label.text = tr("Language")
	_update_subtitles_value(_get_subtitles_enabled())
	_update_god_rays_value(_get_god_rays_enabled())
	_update_language_value(_get_active_locale())


func _update_percent_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(round(value * 100.0))


func _update_subtitles_value(enabled: bool) -> void:
	subtitles_value_label.text = tr("On") if enabled else tr("Off")


func _update_god_rays_value(enabled: bool) -> void:
	god_rays_value_label.text = tr("On") if enabled else tr("Off")


func _get_god_rays_enabled() -> bool:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("get_god_rays_enabled"):
		return bool(settings.call("get_god_rays_enabled"))
	return true


func _update_language_value(locale: String) -> void:
	language_value_label.text = tr("Ukrainian") if locale.begins_with("uk") else tr("English (UK)")


func _get_active_locale() -> String:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("get_locale"):
		return str(settings.call("get_locale"))
	return TranslationServer.get_locale()


func _get_subtitles_enabled() -> bool:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("get_subtitles_enabled"):
		return bool(settings.call("get_subtitles_enabled"))
	return true


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _apply_slider_grabber_icons() -> void:
	var grabber: Texture2D = _build_slider_grabber_texture()
	music_slider.add_theme_icon_override("grabber", grabber)
	music_slider.add_theme_icon_override("grabber_highlight", grabber)
	sounds_slider.add_theme_icon_override("grabber", grabber)
	sounds_slider.add_theme_icon_override("grabber_highlight", grabber)


func _build_slider_grabber_texture() -> Texture2D:
	var image := Image.create(SLIDER_GRABBER_SIZE, SLIDER_GRABBER_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2((SLIDER_GRABBER_SIZE - 1) * 0.5, (SLIDER_GRABBER_SIZE - 1) * 0.5)
	var aa_width := 1.25
	for y in range(SLIDER_GRABBER_SIZE):
		for x in range(SLIDER_GRABBER_SIZE):
			var point := Vector2(float(x), float(y))
			var distance := point.distance_to(center)
			var edge_alpha := clampf((SLIDER_GRABBER_RADIUS - distance) / aa_width, 0.0, 1.0)
			if edge_alpha <= 0.0:
				continue
			var pixel := COLOR_MID_BLUE
			pixel.a = edge_alpha
			image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	return texture
