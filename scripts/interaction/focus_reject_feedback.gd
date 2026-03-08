extends RefCounted
class_name FocusRejectFeedback


var duration := 0.32
var _item
var _remaining := 0.0


func reset() -> void:
	_item = null
	_remaining = 0.0


func trigger(item) -> void:
	if item == null:
		return
	_item = item
	_remaining = duration


func tick(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining == 0.0:
		_item = null


func get_offset(item, base_target_pos: Vector3, slot_position: Vector3) -> Vector3:
	if _item == null or item != _item:
		return Vector3.ZERO
	if _remaining <= 0.0:
		return Vector3.ZERO

	var t := 1.0 - (_remaining / maxf(0.001, duration))
	var pulse := sin(t * PI)
	return (slot_position - base_target_pos) * pulse
