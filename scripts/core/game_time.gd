extends Node

const DEFAULT_START_HOUR := 17
const SECONDS_PER_DAY := 86400.0

@export var time_scale := 1.0

var _seconds_of_day := float(DEFAULT_START_HOUR * 3600)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if time_scale <= 0.0:
		return
	_seconds_of_day = fposmod(_seconds_of_day + delta * time_scale, SECONDS_PER_DAY)


func start_new_game(start_hour: int = DEFAULT_START_HOUR, start_minute: int = 0, start_second: float = 0.0) -> void:
	var clamped_hour := clampi(start_hour, 0, 23)
	var clamped_minute := clampi(start_minute, 0, 59)
	var clamped_second := clampf(start_second, 0.0, 59.999)
	_seconds_of_day = float(clamped_hour * 3600 + clamped_minute * 60) + clamped_second


func load_save_state(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if not data.has("seconds_of_day"):
		return false
	var raw_seconds: float = float(data.get("seconds_of_day", 0.0))
	_seconds_of_day = fposmod(float(raw_seconds), SECONDS_PER_DAY)
	return true


func get_save_state() -> Dictionary:
	return {
		"seconds_of_day": _seconds_of_day
	}


func get_clock_time() -> Dictionary:
	var hour_24: int = int(floor(_seconds_of_day / 3600.0)) % 24
	var minute: int = int(floor(fposmod(_seconds_of_day, 3600.0) / 60.0))
	var second: float = fposmod(_seconds_of_day, 60.0)
	return {
		"hour": hour_24,
		"minute": minute,
		"second": second
	}
