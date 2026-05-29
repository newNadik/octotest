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
@onready var ambience_label: Label = $TopContainer/MainContainer/SettingsRows/AmbienceRow/AmbienceLabel
@onready var ambience_slider: HSlider = $TopContainer/MainContainer/SettingsRows/AmbienceRow/AmbienceSlider
@onready var ambience_value: Label = $TopContainer/MainContainer/SettingsRows/AmbienceRow/AmbienceValue
@onready var voice_label: Label = $TopContainer/MainContainer/SettingsRows/VoiceRow/VoiceLabel
@onready var voice_slider: HSlider = $TopContainer/MainContainer/SettingsRows/VoiceRow/VoiceSlider
@onready var voice_value: Label = $TopContainer/MainContainer/SettingsRows/VoiceRow/VoiceValue
@onready var subtitles_label: Label = $TopContainer/MainContainer/SettingsRows/SubtitlesRow/SubtitlesLabel
@onready var subtitles_on_button: Button = $TopContainer/MainContainer/SettingsRows/SubtitlesRow/SubtitlesSelector/SubtitlesOnButton
@onready var subtitles_off_button: Button = $TopContainer/MainContainer/SettingsRows/SubtitlesRow/SubtitlesSelector/SubtitlesOffButton
@onready var language_label: Label = $TopContainer/MainContainer/SettingsRows/LanguageRow/LanguageLabel
@onready var language_en_button: Button = $TopContainer/MainContainer/SettingsRows/LanguageRow/LanguageSelector/LanguageEnButton
@onready var language_uk_button: Button = $TopContainer/MainContainer/SettingsRows/LanguageRow/LanguageSelector/LanguageUkButton
@onready var shadows_label: Label = $TopContainer/MainContainer/SettingsRows/ShadowsRow/ShadowsLabel
@onready var shadows_on_button: Button = $TopContainer/MainContainer/SettingsRows/ShadowsRow/ShadowsSelector/ShadowsOnButton
@onready var shadows_off_button: Button = $TopContainer/MainContainer/SettingsRows/ShadowsRow/ShadowsSelector/ShadowsOffButton

var _is_updating_ui := false
var _seg_style_left_sel: StyleBoxFlat
var _seg_style_left_unsel: StyleBoxFlat
var _seg_style_right_sel: StyleBoxFlat
var _seg_style_right_unsel: StyleBoxFlat


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS if is_overlay else Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS if is_overlay else Node.PROCESS_MODE_INHERIT
	back_button.pressed.connect(_on_back_pressed)
	music_slider.value_changed.connect(_on_music_changed)
	sounds_slider.value_changed.connect(_on_sounds_changed)
	ambience_slider.value_changed.connect(_on_ambience_changed)
	voice_slider.value_changed.connect(_on_voice_changed)
	subtitles_on_button.pressed.connect(_on_subtitles_select.bind(true))
	subtitles_off_button.pressed.connect(_on_subtitles_select.bind(false))
	language_en_button.pressed.connect(_on_language_select.bind(LOCALE_EN_GB))
	language_uk_button.pressed.connect(_on_language_select.bind(LOCALE_UK_UA))
	shadows_on_button.pressed.connect(_on_shadows_select.bind(true))
	shadows_off_button.pressed.connect(_on_shadows_select.bind(false))
	_apply_slider_grabber_icons()
	_init_seg_styles()
	_load_settings_into_ui()
	_apply_localized_text()
	_grab_initial_focus()


func _grab_initial_focus() -> void:
	if back_button == null:
		return
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


func _on_ambience_changed(value: float) -> void:
	if _is_updating_ui:
		return
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_ambience_volume"):
		settings.call("set_ambience_volume", value)
	_update_percent_label(ambience_value, value)


func _on_voice_changed(value: float) -> void:
	if _is_updating_ui:
		return
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_voice_volume"):
		settings.call("set_voice_volume", value)
	_update_percent_label(voice_value, value)


func _on_shadows_select(enabled: bool) -> void:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_shadows_enabled"):
		settings.call("set_shadows_enabled", enabled)
	_update_shadows_value(enabled)


func _on_subtitles_select(enabled: bool) -> void:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_subtitles_enabled"):
		settings.call("set_subtitles_enabled", enabled)
	_update_subtitles_value(enabled)


func _on_language_select(locale: String) -> void:
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
	var ambience := 1.0
	var voice := 1.0
	var subtitles_enabled := true
	var shadows_enabled := true
	var locale: String = TranslationServer.get_locale()
	if settings != null:
		if settings.has_method("get_music_volume"):
			music = float(settings.call("get_music_volume"))
		if settings.has_method("get_sound_volume"):
			sounds = float(settings.call("get_sound_volume"))
		if settings.has_method("get_ambience_volume"):
			ambience = float(settings.call("get_ambience_volume"))
		if settings.has_method("get_voice_volume"):
			voice = float(settings.call("get_voice_volume"))
		if settings.has_method("get_subtitles_enabled"):
			subtitles_enabled = bool(settings.call("get_subtitles_enabled"))
		if settings.has_method("get_shadows_enabled"):
			shadows_enabled = bool(settings.call("get_shadows_enabled"))
		if settings.has_method("get_locale"):
			locale = str(settings.call("get_locale"))

	music_slider.value = music
	sounds_slider.value = sounds
	ambience_slider.value = ambience
	voice_slider.value = voice
	_update_percent_label(music_value, music)
	_update_percent_label(sounds_value, sounds)
	_update_percent_label(ambience_value, ambience)
	_update_percent_label(voice_value, voice)
	_update_subtitles_value(subtitles_enabled)
	_update_shadows_value(shadows_enabled)
	_update_language_value(locale)
	_is_updating_ui = false


func _apply_localized_text() -> void:
	title_label.text = tr("Settings")
	music_label.text = tr("Music")
	sounds_label.text = tr("Sound Effects")
	ambience_label.text = tr("Ambience")
	voice_label.text = tr("Voice")
	subtitles_label.text = tr("Subtitles")
	language_label.text = tr("Language")
	shadows_label.text = tr("Shadows")
	_update_subtitles_value(_get_subtitles_enabled())
	_update_shadows_value(_get_shadows_enabled())
	_update_language_value(_get_active_locale())


func _update_percent_label(label: Label, value: float) -> void:
	label.text = "%d%%" % int(round(value * 100.0))


func _update_subtitles_value(enabled: bool) -> void:
	subtitles_on_button.text = tr("On")
	subtitles_off_button.text = tr("Off")
	_apply_seg_buttons(subtitles_on_button, subtitles_off_button, enabled)


func _update_shadows_value(enabled: bool) -> void:
	shadows_on_button.text = tr("On")
	shadows_off_button.text = tr("Off")
	_apply_seg_buttons(shadows_on_button, shadows_off_button, enabled)


func _update_language_value(locale: String) -> void:
	_apply_seg_buttons(language_en_button, language_uk_button, not locale.begins_with("uk"))


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


func _get_shadows_enabled() -> bool:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("get_shadows_enabled"):
		return bool(settings.call("get_shadows_enabled"))
	return true


func _init_seg_styles() -> void:
	var sel_bg := COLOR_MID_BLUE
	var unsel_bg := Color(0.42352942, 0.7529412, 1.0)
	_seg_style_left_sel = _make_seg_style(sel_bg, 4, 0, 0, 4)
	_seg_style_left_unsel = _make_seg_style(unsel_bg, 4, 0, 0, 4)
	_seg_style_right_sel = _make_seg_style(sel_bg, 0, 4, 4, 0)
	_seg_style_right_unsel = _make_seg_style(unsel_bg, 0, 4, 4, 0)


func _make_seg_style(bg: Color, tl: int, top_right: int, br: int, bl: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bg
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = tl
	s.corner_radius_top_right = top_right
	s.corner_radius_bottom_right = br
	s.corner_radius_bottom_left = bl
	return s


func _apply_seg_buttons(left_btn: Button, right_btn: Button, left_active: bool) -> void:
	var color_white := Color(0.9497966, 0.9789153, 0.99908715)
	var color_dark := Color(0.019607844, 0.06666667, 0.13333334)
	var left_normal := _seg_style_left_sel if left_active else _seg_style_left_unsel
	var right_normal := _seg_style_right_unsel if left_active else _seg_style_right_sel
	left_btn.add_theme_stylebox_override("normal", left_normal)
	left_btn.add_theme_stylebox_override("hover", _seg_style_left_sel)
	left_btn.add_theme_stylebox_override("pressed", _seg_style_left_sel)
	left_btn.add_theme_stylebox_override("focus", left_normal)
	left_btn.add_theme_color_override("font_color", color_white if left_active else color_dark)
	left_btn.add_theme_color_override("font_hover_color", color_white)
	left_btn.add_theme_color_override("font_pressed_color", color_white)
	left_btn.add_theme_color_override("font_focus_color", color_white if left_active else color_dark)
	right_btn.add_theme_stylebox_override("normal", right_normal)
	right_btn.add_theme_stylebox_override("hover", _seg_style_right_sel)
	right_btn.add_theme_stylebox_override("pressed", _seg_style_right_sel)
	right_btn.add_theme_stylebox_override("focus", right_normal)
	right_btn.add_theme_color_override("font_color", color_dark if left_active else color_white)
	right_btn.add_theme_color_override("font_hover_color", color_white)
	right_btn.add_theme_color_override("font_pressed_color", color_white)
	right_btn.add_theme_color_override("font_focus_color", color_dark if left_active else color_white)


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _apply_slider_grabber_icons() -> void:
	var grabber: Texture2D = _build_slider_grabber_texture()
	music_slider.add_theme_icon_override("grabber", grabber)
	music_slider.add_theme_icon_override("grabber_highlight", grabber)
	sounds_slider.add_theme_icon_override("grabber", grabber)
	sounds_slider.add_theme_icon_override("grabber_highlight", grabber)
	ambience_slider.add_theme_icon_override("grabber", grabber)
	ambience_slider.add_theme_icon_override("grabber_highlight", grabber)
	voice_slider.add_theme_icon_override("grabber", grabber)
	voice_slider.add_theme_icon_override("grabber_highlight", grabber)


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
