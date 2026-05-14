extends StaticBody3D

@export var interactable_path: NodePath = NodePath("Interactable")
@export var animation_player_path: NodePath
@export var audio_player_path: NodePath = NodePath("CarrySfx")
@export var carry_animation_name := ""
@export_range(1, 10, 1) var carry_animation_loops := 5

var _interactable: Interactable
var _animation_player: AnimationPlayer
var _audio_player: AudioStreamPlayer3D
var _active_animation_name := ""
var _playback_time_left := 0.0


func _ready() -> void:
	set_process(true)
	_interactable = get_node_or_null(interactable_path) as Interactable
	_animation_player = _resolve_animation_player()
	_audio_player = _resolve_audio_player()

	if _interactable != null:
		if _interactable.has_signal("picked_up") and not _interactable.picked_up.is_connected(_on_picked_up):
			_interactable.picked_up.connect(_on_picked_up)
		if _interactable.has_signal("dropped") and not _interactable.dropped.is_connected(_on_dropped):
			_interactable.dropped.connect(_on_dropped)

	_force_initial_pose()


func _process(delta: float) -> void:
	if _playback_time_left <= 0.0:
		return

	_playback_time_left = maxf(0.0, _playback_time_left - delta)
	if _playback_time_left > 0.0:
		if _animation_player != null and not _active_animation_name.is_empty() and not _animation_player.is_playing():
			_play_one_cycle()
		return

	if _animation_player != null and _animation_player.is_playing():
		_animation_player.stop()
	if _animation_player != null and not _active_animation_name.is_empty() and _animation_player.has_animation(_active_animation_name):
		_animation_player.seek(0.0, true)
	if _audio_player != null and _audio_player.playing:
		_audio_player.stop()


func _resolve_animation_player() -> AnimationPlayer:
	if not animation_player_path.is_empty():
		return get_node_or_null(animation_player_path) as AnimationPlayer

	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer:
			return node as AnimationPlayer
		for child in node.get_children():
			stack.push_back(child)
	return null


func _resolve_audio_player() -> AudioStreamPlayer3D:
	if not audio_player_path.is_empty():
		var explicit := get_node_or_null(audio_player_path) as AudioStreamPlayer3D
		if explicit != null:
			return explicit

	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AudioStreamPlayer3D:
			return node as AudioStreamPlayer3D
		for child in node.get_children():
			stack.push_back(child)
	return null


func _resolve_animation_name() -> String:
	if _animation_player == null:
		return ""
	if not carry_animation_name.is_empty() and _animation_player.has_animation(carry_animation_name):
		return carry_animation_name

	for candidate in _animation_player.get_animation_list():
		if candidate != "RESET":
			return candidate

	return ""


func _force_initial_pose() -> void:
	if _animation_player == null:
		return

	var reset_name := "RESET" if _animation_player.has_animation("RESET") else _resolve_animation_name()
	if reset_name.is_empty():
		return

	_animation_player.play(reset_name)
	_animation_player.seek(0.0, true)
	_animation_player.stop()


func _on_picked_up(_interactable_ref: Interactable, _actor: Node) -> void:
	if _animation_player == null:
		return

	_active_animation_name = _resolve_animation_name()
	if _active_animation_name.is_empty():
		return

	var clip := _animation_player.get_animation(_active_animation_name)
	if clip == null:
		_playback_time_left = 0.0
		return
	_playback_time_left = clip.length * float(maxi(1, carry_animation_loops))
	_play_one_cycle()


func _on_dropped(_interactable_ref: Interactable, _actor: Node) -> void:
	_playback_time_left = 0.0
	if _animation_player == null:
		return

	if not _active_animation_name.is_empty() and _animation_player.is_playing():
		_animation_player.stop()
	if not _active_animation_name.is_empty() and _animation_player.has_animation(_active_animation_name):
		_animation_player.seek(0.0, true)
	if _audio_player != null and _audio_player.playing:
		_audio_player.stop()


func _play_one_cycle() -> void:
	if _animation_player == null or _active_animation_name.is_empty():
		return
	_animation_player.play(_active_animation_name)
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.play()
