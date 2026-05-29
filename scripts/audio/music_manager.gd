extends Node

enum MusicSlot {
	NONE,
	MENU,
	GAME_START,
	GAME_LOOP,
	LAST_SCENE
}

@export_group("Tracks")
@export var menu_music: AudioStream = preload("res://assets/sound/menu/freecompress-folk_acoustic_music-friend-143409.mp3")
@export var game_start_music: AudioStream = preload("res://assets/sound/game_start/freecompress-wanderingarc-lost-in-the-wet-hillside-reverie-03-relaxing-ambient-music-230244.mp3")
@export var game_loop_music: AudioStream
@export var game_loop_music_tracks: Array[AudioStream] = [preload("res://assets/sound/game_loop/freecompress-wanderingarc-whispering-raindrops-hillside-reverie-02-relaxing-ambient-music-230246.mp3"), 
preload("res://assets/sound/game_loop/freecompress-wanderingarc-home-before-rain-hillside-reverie-01-relaxing-ambient-music-230245.mp3")]
@export var last_scene_music: AudioStream = preload("res://assets/sound/last_scene/freecompress-orangery-magic-moment-164576.mp3")

@export_group("Mix")
@export var default_fade_seconds := 1.2
@export var game_start_to_loop_fade_seconds := 2.0
@export var game_start_to_loop_lead_seconds := 0.35
@export var volume_db := -10.0
@export var game_loop_shuffle := true

var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer
var _game_loop_timer: Timer
var _current_slot := MusicSlot.NONE
var _rng := RandomNumberGenerator.new()
var _game_loop_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_player_a = _new_player("MusicA")
	_player_b = _new_player("MusicB")
	_player_a.finished.connect(_on_player_finished.bind(_player_a))
	_player_b.finished.connect(_on_player_finished.bind(_player_b))
	_active_player = _player_a
	_game_loop_timer = Timer.new()
	_game_loop_timer.name = "GameLoopTimer"
	_game_loop_timer.one_shot = true
	_game_loop_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_game_loop_timer.timeout.connect(_on_game_loop_timer_timeout)
	add_child(_game_loop_timer)


func play_menu(fade_seconds: float = -1.0) -> void:
	_set_slot(MusicSlot.MENU, menu_music, fade_seconds)


func play_game_start(fade_seconds: float = -1.0) -> void:
	_set_slot(MusicSlot.GAME_START, game_start_music, fade_seconds)
	_schedule_game_loop_transition()


func play_game_loop(fade_seconds: float = -1.0) -> void:
	var next_track := _get_next_game_loop_track()
	_set_slot(MusicSlot.GAME_LOOP, next_track, fade_seconds)


func play_last_scene(fade_seconds: float = -1.0) -> void:
	_set_slot(MusicSlot.LAST_SCENE, last_scene_music, fade_seconds)


func stop_music(fade_seconds: float = -1.0) -> void:
	_cancel_scheduled_transition()
	var fade := _resolve_fade(fade_seconds, default_fade_seconds)
	if _active_player.playing:
		if fade <= 0.01:
			_active_player.stop()
			_active_player.volume_db = volume_db
		else:
			var tween := create_tween()
			tween.tween_property(_active_player, "volume_db", -80.0, fade)
			await tween.finished
			_active_player.stop()
			_active_player.volume_db = volume_db
	_current_slot = MusicSlot.NONE


func _set_slot(slot: MusicSlot, stream: AudioStream, fade_seconds: float) -> void:
	_cancel_scheduled_transition()
	if stream == null:
		push_warning("Music track is not assigned for slot %s." % MusicSlot.keys()[slot])
		return
	if _current_slot == slot and _active_player.playing and _active_player.stream == stream:
		return
	_crossfade_to(stream, _resolve_fade(fade_seconds, default_fade_seconds))
	_current_slot = slot


func _crossfade_to(stream: AudioStream, fade: float) -> void:
	var incoming := _player_b if _active_player == _player_a else _player_a
	incoming.stream = stream
	incoming.bus = _resolve_music_bus_name()
	incoming.volume_db = -80.0 if fade > 0.01 else volume_db
	incoming.play()

	if fade <= 0.01:
		if _active_player.playing:
			_active_player.stop()
		incoming.volume_db = volume_db
		_active_player = incoming
		return

	var outgoing := _active_player
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", volume_db, fade)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", -80.0, fade)
	await tween.finished
	if outgoing.playing:
		outgoing.stop()
	outgoing.volume_db = volume_db
	_active_player = incoming


func _schedule_game_loop_transition() -> void:
	if game_start_music == null:
		return
	if _valid_game_loop_tracks().is_empty() and game_loop_music == null:
		return
	var track_length := game_start_music.get_length()
	if track_length <= 0.0:
		return
	var wait_time := maxf(0.1, track_length - maxf(0.0, game_start_to_loop_lead_seconds))
	_game_loop_timer.start(wait_time)


func _cancel_scheduled_transition() -> void:
	if _game_loop_timer != null:
		_game_loop_timer.stop()


func _on_game_loop_timer_timeout() -> void:
	if _current_slot != MusicSlot.GAME_START:
		return
	play_game_loop(game_start_to_loop_fade_seconds)


func _on_player_finished(player: AudioStreamPlayer) -> void:
	if player != _active_player:
		return
	match _current_slot:
		MusicSlot.MENU:
			play_menu(0.2)
		MusicSlot.GAME_LOOP:
			play_game_loop(0.2)
		_:
			return


func _get_next_game_loop_track() -> AudioStream:
	var tracks := _valid_game_loop_tracks()
	if tracks.is_empty():
		return game_loop_music
	if game_loop_shuffle:
		var next := _rng.randi_range(0, tracks.size() - 1)
		if tracks.size() > 1 and next == _game_loop_index:
			next = (next + 1) % tracks.size()
		_game_loop_index = next
		return tracks[_game_loop_index]
	_game_loop_index = (_game_loop_index + 1) % tracks.size()
	return tracks[_game_loop_index]


func _valid_game_loop_tracks() -> Array[AudioStream]:
	var tracks: Array[AudioStream] = []
	for track in game_loop_music_tracks:
		if track != null:
			tracks.append(track)
	return tracks


func _resolve_fade(fade_seconds: float, fallback: float) -> float:
	return fallback if fade_seconds < 0.0 else maxf(0.0, fade_seconds)


func _new_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = _resolve_music_bus_name()
	player.volume_db = volume_db
	add_child(player)
	return player


func _resolve_music_bus_name() -> String:
	return "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
