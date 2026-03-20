extends Control


const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SETTINGS_MENU_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const ABOUT_POPUP_SCENE := preload("res://scenes/ui/about_popup.tscn")
const CONTACT_POPUP_SCENE := preload("res://scenes/ui/contact_popup.tscn")
const STAFF_ACCESS_POPUP_SCENE := preload("res://scenes/ui/staff_access_popup.tscn")
const SLIDESHOW_TEXTURE_PATHS := [
	"res://assets/ui/slideshow/1.jpg",
	"res://assets/ui/slideshow/2.jpg",
	"res://assets/ui/slideshow/3.jpeg",
	"res://assets/ui/slideshow/4.jpg"
]
const FLAG_UK_PATH := "res://assets/ui/united-kingdom.png"
const FLAG_UA_PATH := "res://assets/ui/ukraine.png"
const LOCALE_EN_GB := "en_GB"
const LOCALE_UK_UA := "uk_UA"
const LANGUAGE_ICON_MAX_WIDTH := 24
const LANGUAGE_ARROW_COLOR := Color("0d243d")
const LANGUAGE_POPUP_BG_COLOR := Color("6cc0ff")
const DISPLAY_REFLECTION_MAX_OFFSET := Vector2(0.06, 0.04)
const DISPLAY_REFLECTION_SMOOTH_SPEED := 10.0

@onready var play_button: Button = $MainVBoxContainer/MainContainer/HBoxContainer/LeftContent/MenuButtons/PlayButton
@onready var load_game_button: Button = $MainVBoxContainer/MainContainer/HBoxContainer/LeftContent/MenuButtons/LoadGameButton
@onready var settings_button: Button = $MainVBoxContainer/MainContainer/HBoxContainer/LeftContent/MenuButtons/SettingsButton
@onready var quit_button: Button = $MainVBoxContainer/MainContainer/HBoxContainer/LeftContent/MenuButtons/QuitButton
@onready var slide_dots_label: Label = $MainVBoxContainer/MainContainer/HBoxContainer/CarouselPanel/CarouselControls/SlideDotsLabel
@onready var slide_timer: Timer = $SlideTimer
@onready var slides_root: Control = $MainVBoxContainer/MainContainer/HBoxContainer/CarouselPanel/SlidesHost/Slides
@onready var nav_buttons: HBoxContainer = $MainVBoxContainer/TopPanelContainer/TopContainer/HeaderRow/NavButtons
@onready var bottom_nav_buttons: HBoxContainer = $MainVBoxContainer/BottomPanelContainer/MarginContainer/HBoxContainer/BottomNavButtons
@onready var language_select: OptionButton = $MainVBoxContainer/BottomPanelContainer/MarginContainer/HBoxContainer/LanguageSelect
@onready var display_fx: ColorRect = $DisplayFX
@onready var main_vbox: VBoxContainer = $MainVBoxContainer
@onready var sticker_container: Control = $StickerContainer

var _slides: Array[Control] = []
var _slide_index := 0
var _display_material: ShaderMaterial
var _display_reflection_offset := Vector2.ZERO
var _settings_overlay: Control
var _info_popup_overlay: Control
var _popup_layer: CanvasLayer


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	slide_timer.timeout.connect(_on_slide_timer_timeout)
	_collect_slides()
	_assign_slide_textures()
	_show_slide(0)
	_setup_nav_links()
	_setup_language_select()
	_setup_display_parallax()
	_ensure_popup_layer()
	play_button.grab_focus()


func _on_play_pressed() -> void:
	var error := get_tree().change_scene_to_file(GAME_SCENE_PATH)
	if error != OK:
		push_error("Failed to load game scene: %s" % GAME_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_load_game_pressed() -> void:
	push_warning("Load Game is not implemented yet.")


func _on_settings_pressed() -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		return
	var settings_menu := SETTINGS_MENU_SCENE.instantiate() as Control
	settings_menu.set("is_overlay", true)
	settings_menu.z_index = 100
	settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_menu.anchor_right = 1.0
	settings_menu.anchor_bottom = 1.0
	settings_menu.closed.connect(_on_settings_overlay_closed)
	add_child(settings_menu)
	settings_menu.move_to_front()
	settings_menu.show()
	_settings_overlay = settings_menu
	_set_base_menu_visible(false)


func _on_settings_overlay_closed() -> void:
	_close_settings_overlay()


func _close_settings_overlay() -> void:
	if _settings_overlay == null:
		return
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
	_settings_overlay = null
	_set_base_menu_visible(true)
	_sync_language_select_selection()
	settings_button.grab_focus()


func _set_base_menu_visible(visible: bool) -> void:
	main_vbox.visible = visible
	display_fx.visible = visible
	sticker_container.visible = visible


func _collect_slides() -> void:
	for child: Node in slides_root.get_children():
		if child is Control:
			_slides.append(child as Control)


func _assign_slide_textures() -> void:
	for i in min(_slides.size(), SLIDESHOW_TEXTURE_PATHS.size()):
		var slide := _slides[i]
		var image := slide.get_node_or_null("SlideImage") as TextureRect
		if image == null:
			continue
		var texture := load(SLIDESHOW_TEXTURE_PATHS[i]) as Texture2D
		if texture == null:
			push_warning("Missing slideshow texture: %s" % SLIDESHOW_TEXTURE_PATHS[i])
			continue
		image.texture = texture


func _show_slide(index: int) -> void:
	if _slides.is_empty():
		return
	_slide_index = wrapi(index, 0, _slides.size())
	for i in _slides.size():
		_slides[i].visible = i == _slide_index
	slide_dots_label.text = _build_dots(_slide_index, _slides.size())


func _on_slide_timer_timeout() -> void:
	_show_slide(_slide_index + 1)


func _build_dots(active_index: int, total: int) -> String:
	var dots: Array[String] = []
	for i in total:
		dots.append("●" if i == active_index else "○")
	return " ".join(dots)


func _process(delta: float) -> void:
	if _display_material == null:
		return
	var size: Vector2 = display_fx.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var mouse_local: Vector2 = display_fx.get_local_mouse_position()
	var normalized := Vector2(
		clampf(mouse_local.x / size.x, 0.0, 1.0),
		clampf(mouse_local.y / size.y, 0.0, 1.0)
	) - Vector2(0.5, 0.5)
	var target_offset := Vector2(
		-normalized.x * DISPLAY_REFLECTION_MAX_OFFSET.x,
		-normalized.y * DISPLAY_REFLECTION_MAX_OFFSET.y
	)
	var lerp_weight := clampf(delta * DISPLAY_REFLECTION_SMOOTH_SPEED, 0.0, 1.0)
	_display_reflection_offset = _display_reflection_offset.lerp(target_offset, lerp_weight)
	_display_material.set_shader_parameter("reflection_offset", _display_reflection_offset)


func _setup_display_parallax() -> void:
	_display_material = display_fx.material as ShaderMaterial
	set_process(_display_material != null)
	if _display_material == null:
		return
	_display_material.set_shader_parameter("reflection_offset", Vector2.ZERO)


func _setup_nav_links() -> void:
	_setup_nav_links_for(nav_buttons)
	_setup_nav_links_for(bottom_nav_buttons)


func _setup_nav_links_for(container: HBoxContainer) -> void:
	for child: Node in container.get_children():
		var control := child as Control
		if control == null:
			continue
		var label := control as Label
		if label != null:
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			label.mouse_entered.connect(_on_nav_label_mouse_entered.bind(label))
			label.mouse_exited.connect(_on_nav_label_mouse_exited.bind(label))
			label.gui_input.connect(_on_nav_label_gui_input.bind(label))
			_ensure_nav_underline(label)
			continue
		var button := control as BaseButton
		if button != null:
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.pressed.connect(_on_nav_button_pressed.bind(button))


func _ensure_nav_underline(label: Label) -> void:
	if label.has_node("Underline"):
		return
	var underline := ColorRect.new()
	underline.name = "Underline"
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underline.color = Color(0.050980393, 0.14117648, 0.23921569, 0.95)
	underline.anchor_left = 0.0
	underline.anchor_top = 1.0
	underline.anchor_right = 1.0
	underline.anchor_bottom = 1.0
	underline.offset_top = -2.0
	underline.offset_bottom = 0.0
	underline.visible = false
	label.add_child(underline)


func _on_nav_label_mouse_entered(label: Label) -> void:
	var underline := label.get_node_or_null("Underline") as ColorRect
	if underline != null:
		underline.visible = true


func _on_nav_label_mouse_exited(label: Label) -> void:
	var underline := label.get_node_or_null("Underline") as ColorRect
	if underline != null:
		underline.visible = false


func _on_nav_label_gui_input(event: InputEvent, label: Label) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	var popup_scene := _resolve_popup_scene(label)
	if popup_scene != null:
		_show_info_popup(popup_scene)
		return
	push_warning("%s section is not implemented yet." % label.text)


func _on_nav_button_pressed(button: BaseButton) -> void:
	if button == null:
		return
	var popup_scene := _resolve_popup_scene(button)
	if popup_scene != null:
		_show_info_popup(popup_scene)
		return
	push_warning("%s section is not implemented yet." % button.text)


func _setup_language_select() -> void:
	language_select.clear()
	var uk_icon := load(FLAG_UK_PATH) as Texture2D
	var ua_icon := load(FLAG_UA_PATH) as Texture2D
	language_select.fit_to_longest_item = false
	var uk_small := _scaled_icon(uk_icon, LANGUAGE_ICON_MAX_WIDTH)
	var ua_small := _scaled_icon(ua_icon, LANGUAGE_ICON_MAX_WIDTH)
	if uk_small != null:
		language_select.add_icon_item(uk_small, "")
	else:
		language_select.add_item("")
	if ua_small != null:
		language_select.add_icon_item(ua_small, "")
	else:
		language_select.add_item("")
	var popup := language_select.get_popup()
	for i in popup.item_count:
		popup.set_item_as_checkable(i, false)
	language_select.add_theme_color_override("font_color", LANGUAGE_ARROW_COLOR)
	language_select.add_theme_color_override("font_hover_color", LANGUAGE_ARROW_COLOR)
	language_select.add_theme_color_override("font_pressed_color", LANGUAGE_ARROW_COLOR)
	language_select.add_theme_color_override("font_focus_color", LANGUAGE_ARROW_COLOR)
	var popup_bg := StyleBoxFlat.new()
	popup_bg.bg_color = LANGUAGE_POPUP_BG_COLOR
	popup_bg.corner_radius_top_left = 6
	popup_bg.corner_radius_top_right = 6
	popup_bg.corner_radius_bottom_right = 6
	popup_bg.corner_radius_bottom_left = 6
	popup.add_theme_stylebox_override("panel", popup_bg)
	_sync_language_select_selection()
	language_select.item_selected.connect(_on_language_selected)


func _on_language_selected(index: int) -> void:
	if index == 0:
		_set_active_locale(LOCALE_EN_GB)
		return
	if index == 1:
		_set_active_locale(LOCALE_UK_UA)


func _get_active_locale() -> String:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("get_locale"):
		return str(settings.call("get_locale"))
	return TranslationServer.get_locale()


func _set_active_locale(locale: String) -> void:
	var settings := _get_game_settings()
	if settings != null and settings.has_method("set_locale"):
		settings.call("set_locale", locale)
		_sync_language_select_selection()
		return
	TranslationServer.set_locale(locale)
	_sync_language_select_selection()


func _get_game_settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _sync_language_select_selection() -> void:
	var locale := _get_active_locale()
	language_select.select(1 if locale.begins_with("uk") else 0)


func _scaled_icon(texture: Texture2D, target_width: int) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	if image.get_width() <= target_width:
		return texture
	var aspect: float = float(image.get_height()) / float(image.get_width())
	var target_height: int = maxi(1, int(round(float(target_width) * aspect)))
	image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _resolve_popup_scene(control: Control) -> PackedScene:
	if control == null:
		return null
	var section_text := ""
	var label := control as Label
	if label != null:
		section_text = label.text
	else:
		var button := control as BaseButton
		if button != null:
			section_text = button.text
	var normalized := section_text.strip_edges().to_lower()
	if normalized == "about" or normalized == "about us":
		return ABOUT_POPUP_SCENE
	if normalized == "contact us":
		return CONTACT_POPUP_SCENE
	if normalized == "staff access" or normalized == "stuff access":
		return STAFF_ACCESS_POPUP_SCENE
	if normalized == "про нас":
		return ABOUT_POPUP_SCENE
	if normalized == "зв'яжіться з нами" or normalized == "контакти":
		return CONTACT_POPUP_SCENE
	if normalized == "доступ для персоналу":
		return STAFF_ACCESS_POPUP_SCENE
	return null


func _show_info_popup(popup_scene: PackedScene) -> void:
	if popup_scene == null:
		return
	_ensure_popup_layer()
	if _info_popup_overlay != null and is_instance_valid(_info_popup_overlay):
		_info_popup_overlay.queue_free()
	var popup := popup_scene.instantiate() as Control
	if popup == null:
		return
	popup.z_index = 1000
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.anchor_right = 1.0
	popup.anchor_bottom = 1.0
	if popup.has_signal("closed"):
		popup.closed.connect(_on_info_popup_closed)
	_popup_layer.add_child(popup)
	popup.move_to_front()
	_info_popup_overlay = popup


func _on_info_popup_closed() -> void:
	if _info_popup_overlay == null:
		return
	if is_instance_valid(_info_popup_overlay):
		_info_popup_overlay.queue_free()
	_info_popup_overlay = null


func _ensure_popup_layer() -> void:
	if _popup_layer != null and is_instance_valid(_popup_layer):
		return
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 20
	add_child(_popup_layer)
