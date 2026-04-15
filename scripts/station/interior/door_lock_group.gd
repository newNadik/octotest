extends Node3D

@export var locked := false
@export var slide_a_path: NodePath = NodePath("door_slide")
@export var slide_b_path: NodePath = NodePath("door_slide2")
var slide_a_open_distance := 1.41
var slide_b_open_distance := 1.35
var synchronize_hover_highlight := true

var _slide_nodes: Array[Node] = []
var _group_highlight_active := false


func _ready() -> void:
	_collect_slide_nodes()
	_apply_open_distance_overrides()
	_connect_slide_signals()
	_apply_locked_state()
	_configure_group_indicator()
	set_process(synchronize_hover_highlight and _slide_nodes.size() > 1)


func _process(_delta: float) -> void:
	if not synchronize_hover_highlight or _slide_nodes.size() < 2:
		return

	var any_highlight := false
	for slide in _slide_nodes:
		if slide == null or not is_instance_valid(slide):
			continue
		if slide.has_method("is_highlight_active_for_group") and bool(slide.call("is_highlight_active_for_group")):
			any_highlight = true
			break

	if any_highlight == _group_highlight_active:
		return
	_group_highlight_active = any_highlight
	_apply_group_hover_highlight(any_highlight)


func set_locked(value: bool) -> void:
	locked = value
	_apply_locked_state()


func lock() -> void:
	set_locked(true)


func unlock() -> void:
	set_locked(false)


func _collect_slide_nodes() -> void:
	_slide_nodes.clear()
	for child in get_children():
		if child != null and child.has_method("set_locked"):
			_slide_nodes.append(child)


func _connect_slide_signals() -> void:
	for slide in _slide_nodes:
		if slide == null or not is_instance_valid(slide):
			continue
		if not slide.has_signal("open_requested"):
			continue
		var handler := Callable(self, "_on_slide_open_requested")
		if not slide.is_connected("open_requested", handler):
			slide.connect("open_requested", handler)


func _apply_locked_state() -> void:
	for slide in _slide_nodes:
		if slide != null and is_instance_valid(slide):
			slide.call("set_locked", locked)


func _apply_open_distance_overrides() -> void:
	_apply_open_distance_override_for_path(slide_a_path, slide_a_open_distance)
	_apply_open_distance_override_for_path(slide_b_path, slide_b_open_distance)


func _apply_open_distance_override_for_path(path: NodePath, distance: float) -> void:
	if distance <= 0.0:
		return
	if path.is_empty():
		return
	var slide = get_node_or_null(path)
	if slide == null or not is_instance_valid(slide):
		return
	if slide.has_method("set_open_distance"):
		slide.call("set_open_distance", distance)


func _on_slide_open_requested(_source: Node) -> void:
	for slide in _slide_nodes:
		if slide != null and is_instance_valid(slide) and slide.has_method("open"):
			slide.call("open")


func _apply_group_hover_highlight(active: bool) -> void:
	for slide in _slide_nodes:
		if slide != null and is_instance_valid(slide) and slide.has_method("set_group_highlight"):
			slide.call("set_group_highlight", active)


func is_group_doorway_blocked() -> bool:
	for slide in _slide_nodes:
		if slide == null or not is_instance_valid(slide):
			continue
		if slide.has_method("is_doorway_blocked") and bool(slide.call("is_doorway_blocked")):
			return true
	return false


func _configure_group_indicator() -> void:
	if _slide_nodes.size() < 2:
		return
	var interactables: Array = []
	for slide in _slide_nodes:
		if slide == null or not is_instance_valid(slide):
			continue
		if slide.has_method("get_interactable"):
			var interactable = slide.call("get_interactable")
			if interactable != null:
				interactables.append(interactable)
	if interactables.size() < 2:
		return

	var midpoint := Vector3.ZERO
	for interactable in interactables:
		if interactable != null and interactable.has_method("get_focus_position"):
			midpoint += interactable.call("get_focus_position")
	midpoint /= float(interactables.size())

	var primary = interactables[0]
	if primary != null and primary.has_method("set_indicator_visible"):
		primary.call("set_indicator_visible", true)
	if primary != null and primary.has_method("set_indicator_world_position_override"):
		primary.call("set_indicator_world_position_override", midpoint + Vector3(0.0, 0.08, 0.0), true)

	for i in range(1, interactables.size()):
		var secondary = interactables[i]
		if secondary != null and secondary.has_method("set_indicator_visible"):
			secondary.call("set_indicator_visible", false)
