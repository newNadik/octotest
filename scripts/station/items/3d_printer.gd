extends Node3D

var _printing_done := false

@export var printing_done := false:
	set(value):
		_printing_done = value
		_set_printing_done_state()
	get:
		return _printing_done

@export var blink_interval := 0.8

@onready var _done_indicator: MeshInstance3D = $RootNode/Sphere/done_indicator

var _blink_elapsed := 0.0


func _ready() -> void:
	_set_printing_done_state()
	set_process(_printing_done)


func _process(delta: float) -> void:
	if not _printing_done or _done_indicator == null:
		return
	_blink_elapsed += delta
	if _blink_elapsed >= blink_interval:
		_blink_elapsed = 0.0
		_done_indicator.visible = not _done_indicator.visible


func _set_printing_done_state() -> void:
	_blink_elapsed = 0.0
	if _done_indicator == null:
		return
	if _printing_done:
		_done_indicator.visible = true
		set_process(true)
	else:
		_done_indicator.visible = false
		set_process(false)
