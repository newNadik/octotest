extends InteractionBehavior
class_name PhotoCameraBehavior

const CAMERA_SOUND_DEFAULT: AudioStream = preload("res://assets/sound/camera_sound.mp3")

@export var camera_sound: AudioStream = CAMERA_SOUND_DEFAULT
@export var camera_sound_volume_db := -7.0
@export var photo_flash_click_delay := 0.11
@export var photo_flash_duration := 0.28
@export var photo_cooldown := 2.0
@export var flash_alpha := 0.5

var _camera_player: AudioStreamPlayer3D
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _locked_until := 0.0


func _ready() -> void:
	_ensure_camera_player()
	_ensure_flash_overlay()


func on_interacted(_actor: Node) -> void:
	if _is_locked():
		return
	_locked_until = (Time.get_ticks_msec() / 1000.0) + photo_cooldown
	_play_camera_sound()
	_trigger_flash()


func _is_locked() -> bool:
	return (Time.get_ticks_msec() / 1000.0) < _locked_until


func _ensure_camera_player() -> void:
	if _camera_player != null and is_instance_valid(_camera_player):
		return
	_camera_player = AudioStreamPlayer3D.new()
	_camera_player.name = "PhotoCameraSoundPlayer"
	_camera_player.max_distance = 20.0
	add_child(_camera_player)


func _play_camera_sound() -> void:
	if _camera_player == null:
		return
	_camera_player.stream = camera_sound
	_camera_player.volume_db = camera_sound_volume_db
	_camera_player.global_position = global_position
	_camera_player.play()


func _ensure_flash_overlay() -> void:
	if _flash_layer != null and is_instance_valid(_flash_layer):
		return
	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "PhotoFlashLayer"
	_flash_layer.layer = 100
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "PhotoFlashRect"
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_layer.add_child(_flash_rect)


func _trigger_flash() -> void:
	if _flash_rect == null or not is_instance_valid(_flash_rect):
		return
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	var delay_timer := get_tree().create_timer(photo_flash_click_delay)
	delay_timer.timeout.connect(func() -> void:
		if _flash_rect == null or not is_instance_valid(_flash_rect):
			return
		_flash_rect.color = Color(1.0, 1.0, 1.0, clampf(flash_alpha, 0.0, 1.0))
		var tween := create_tween()
		tween.tween_property(_flash_rect, "color:a", 0.0, photo_flash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)
