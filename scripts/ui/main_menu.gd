extends Control


const GAME_SCENE_PATH := "res://scenes/main.tscn"
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

var _slides: Array[Control] = []
var _slide_index := 0
var _display_material: ShaderMaterial
var _display_reflection_offset := Vector2.ZERO


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
	push_warning("Settings is not implemented yet.")


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
		var label := child as Label
		if label == null:
			continue
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.mouse_entered.connect(_on_nav_label_mouse_entered.bind(label))
		label.mouse_exited.connect(_on_nav_label_mouse_exited.bind(label))
		label.gui_input.connect(_on_nav_label_gui_input.bind(label.text))
		_ensure_nav_underline(label)


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


func _on_nav_label_gui_input(event: InputEvent, section_name: String) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button == null:
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	if (section_name == "About"):
		push_warning("Add About logic")
	else :
		push_warning("%s section is not implemented yet." % section_name)


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
	language_select.select(0)
	language_select.item_selected.connect(_on_language_selected)


func _on_language_selected(index: int) -> void:
	if index == 0:
		TranslationServer.set_locale(LOCALE_EN_GB)
		return
	if index == 1:
		TranslationServer.set_locale(LOCALE_UK_UA)


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
