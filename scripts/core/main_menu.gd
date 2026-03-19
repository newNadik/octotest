extends Control


const GAME_SCENE_PATH := "res://scenes/main.tscn"
const SLIDESHOW_TEXTURE_PATHS := [
	"res://assets/ui/slideshow/1.jpg",
	"res://assets/ui/slideshow/2.jpg",
	"res://assets/ui/slideshow/3.jpeg",
	"res://assets/ui/slideshow/4.jpg"
]

@onready var play_button: Button = $MainMargin/RootColumn/ContentRow/LeftPanel/LeftMargin/LeftContent/MenuButtons/PlayButton
@onready var quit_button: Button = $MainMargin/RootColumn/ContentRow/LeftPanel/LeftMargin/LeftContent/MenuButtons/QuitButton
@onready var slide_dots_label: Label = $MainMargin/RootColumn/ContentRow/RightPanel/CarouselPanel/CarouselMargin/CarouselLayout/CarouselControls/SlideDotsLabel
@onready var slide_timer: Timer = $SlideTimer
@onready var slides_root: Control = $MainMargin/RootColumn/ContentRow/RightPanel/CarouselPanel/CarouselMargin/CarouselLayout/SlidesHost/Slides

var _slides: Array[Control] = []
var _slide_index := 0


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	slide_timer.timeout.connect(_on_slide_timer_timeout)
	_collect_slides()
	_assign_slide_textures()
	_show_slide(0)
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
