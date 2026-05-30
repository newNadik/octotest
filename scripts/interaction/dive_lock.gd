extends Node3D
class_name DiveLock

enum ControlState { STANDBY, ARMED, RUNNING, SEALED }
enum ChamberState { DRAINED, FLOODED }
enum Operation { NONE, EXIT_STATION, ENTER_STATION, EMERGENCY_SEAL }

@export var numpad_path: NodePath
@export var lever_path: NodePath
@export var lamp_path: NodePath
@export var inner_door_path: NodePath
@export var outer_door_path: NodePath
@export var water_box_path: NodePath

@export var operation_duration: float = 10.0
@export var seal_timeout: float = 60.0
@export var armed_timeout: float = 60.0

const WATER_Y_DRAINED := -4.0
const WATER_Y_FLOODED := 3.5

const ENTER_CODE := "2407"
const SEAL_CODE := "7700"

const COLOR_WHITE  := Color(1.0,  1.0,  1.0)
const COLOR_GREEN  := Color(0.1,  0.9,  0.3)
const COLOR_BLUE   := Color(0.58, 0.74, 1.0)
const COLOR_ORANGE := Color(1.0,  0.55, 0.1)
const COLOR_RED    := Color(0.9,  0.15, 0.15)

var _numpad: Numpad
var _lever: Lever
var _lamp: BulkheadLamp
var _inner_door: Node
var _outer_door: Node
var _water_box: Node3D
var _underwater_box: MeshInstance3D
var _water_tween: Tween

var _control_state := ControlState.STANDBY
var _chamber_state := ChamberState.DRAINED
var _armed_operation := Operation.NONE
var _armed_timer: SceneTreeTimer = null


func _ready() -> void:
	_numpad = get_node(numpad_path)
	_lever = get_node(lever_path)
	_lamp = get_node(lamp_path)
	_inner_door = get_node(inner_door_path)
	_outer_door = get_node(outer_door_path)
	if water_box_path:
		_water_box = get_node_or_null(water_box_path)
		if _water_box != null:
			_underwater_box = _water_box.get_node_or_null("underwater_box") as MeshInstance3D

	_numpad.code_submitted.connect(_on_code_submitted)
	_numpad.input_changed.connect(_on_input_changed)
	_lever.lever_pulled.connect(_on_lever_pulled)

	_enter_standby()


# --- Signal handlers ---

func _on_code_submitted(text: String) -> void:
	if _control_state == ControlState.ARMED:
		_cancel_armed()
		return
	if _control_state != ControlState.STANDBY:
		return

	var exit_code := str(GameSettings.get_exit_code())

	if text == SEAL_CODE:
		_arm(Operation.EMERGENCY_SEAL)
	elif text == exit_code and _chamber_state == ChamberState.DRAINED:
		_arm(Operation.EXIT_STATION)
	elif text == ENTER_CODE and _chamber_state == ChamberState.FLOODED:
		_arm(Operation.ENTER_STATION)
	else:
		_reject()


func _on_input_changed() -> void:
	if _control_state == ControlState.ARMED:
		_cancel_armed()


func _on_lever_pulled() -> void:
	if _control_state != ControlState.ARMED:
		return
	_cancel_armed_timer()
	_start_operation()


# --- State transitions ---

func _arm(operation: Operation) -> void:
	_control_state = ControlState.ARMED
	_armed_operation = operation

	_inner_door.disable()
	_outer_door.disable()

	_lamp.set_beacon(COLOR_BLUE)
	_lever.set_enabled(true)
	_lever.set_indicator_blue_flash()

	match operation:
		Operation.EXIT_STATION:
			_numpad.set_display_text(tr("EXIT STATION\nPULL LEVER"))
		Operation.ENTER_STATION:
			_numpad.set_display_text(tr("ENTER STATION\nPULL LEVER"))
		Operation.EMERGENCY_SEAL:
			_numpad.set_display_text(tr("EMRG SEAL\nPULL LEVER"))

	_armed_timer = get_tree().create_timer(armed_timeout)
	_armed_timer.timeout.connect(_on_armed_timeout)


func _cancel_armed() -> void:
	_cancel_armed_timer()
	_armed_operation = Operation.NONE
	_lever.set_enabled(false)
	_enter_standby()


func _cancel_armed_timer() -> void:
	if _armed_timer != null:
		if _armed_timer.timeout.is_connected(_on_armed_timeout):
			_armed_timer.timeout.disconnect(_on_armed_timeout)
		_armed_timer = null


func _on_armed_timeout() -> void:
	_armed_timer = null
	_cancel_armed()


func _reject() -> void:
	_numpad.set_locked(true)
	_numpad.set_display_text(tr("REJECTED"))
	_lamp.set_beacon(COLOR_RED)
	get_tree().create_timer(1.5).timeout.connect(func():
		_numpad.set_locked(false)
		_enter_standby()
	)


func _start_operation() -> void:
	_control_state = ControlState.RUNNING
	_lever.set_enabled(false)
	_lever.set_indicator_orange()
	_lamp.set_beacon(COLOR_ORANGE)

	if _armed_operation == Operation.EMERGENCY_SEAL:
		_enter_sealed()
		return

	match _armed_operation:
		Operation.EXIT_STATION:
			_numpad.set_display_text(tr("FLOODING"))
			_set_underwater_box_visible(true)
			_tween_water(WATER_Y_FLOODED)
		Operation.ENTER_STATION:
			_numpad.set_display_text(tr("DRAINING"))
			_tween_water(WATER_Y_DRAINED)

	get_tree().create_timer(operation_duration).timeout.connect(_on_operation_complete)


func _on_operation_complete() -> void:
	if _armed_operation == Operation.EXIT_STATION:
		_chamber_state = ChamberState.FLOODED
	else:
		_chamber_state = ChamberState.DRAINED
		_set_underwater_box_visible(false)

	_lever.return_to_up(-1.0, false)
	_enter_standby()


func _enter_sealed() -> void:
	_control_state = ControlState.SEALED
	_numpad.set_locked(true)
	_numpad.set_display_text(tr("SEALED"))
	_lamp.set_beacon(COLOR_RED)
	_lever.set_indicator_red_flash()
	_lever.return_to_up(seal_timeout, false)

	get_tree().create_timer(seal_timeout).timeout.connect(_on_seal_timeout)


func _on_seal_timeout() -> void:
	_numpad.set_locked(false)
	_enter_standby()


func _enter_standby() -> void:
	_control_state = ControlState.STANDBY
	_armed_operation = Operation.NONE

	_lever.set_enabled(false)
	_lever.set_indicator_off()
	_numpad.set_display_text(tr("ENTER CODE"))
	_numpad.clear_input()

	match _chamber_state:
		ChamberState.DRAINED:
			_inner_door.unlock()
			_outer_door.disable()
			_lamp.set_steady(COLOR_WHITE)
			_set_water_y(WATER_Y_DRAINED)
			_set_underwater_box_visible(false)
		ChamberState.FLOODED:
			_inner_door.disable()
			_outer_door.unlock()
			_lamp.set_steady(COLOR_GREEN)
			_set_water_y(WATER_Y_FLOODED)
			_set_underwater_box_visible(true)


func _set_underwater_box_visible(visible: bool) -> void:
	if _underwater_box != null:
		_underwater_box.visible = visible


func _tween_water(target_y: float) -> void:
	if _water_box == null:
		return
	if _water_tween:
		_water_tween.kill()
	_water_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_water_tween.tween_property(_water_box, "position:y", target_y, operation_duration)


func _set_water_y(y: float) -> void:
	if _water_box == null:
		return
	var pos := _water_box.position
	pos.y = y
	_water_box.position = pos
