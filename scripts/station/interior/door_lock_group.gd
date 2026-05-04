extends Node3D

enum AccessMode {
	DISABLED,
	UNLOCKED,
	CARD_LOCKED,
}

@export var access_mode: AccessMode = AccessMode.UNLOCKED
@export var locked := false
@export_group("Door Metadata")
@export var privacy_glass_enabled := false
@export var door_title := ""
@export var door_title_secondary := ""
@export_enum("Front", "Back") var title_side := 0
@export var slide_a_path: NodePath = NodePath("door_slide")
@export var slide_b_path: NodePath = NodePath("door_slide2")
var slide_a_open_distance := 1.41
var slide_b_open_distance := 1.35
var synchronize_hover_highlight := true

var _slide_nodes: Array[Node] = []
var _group_highlight_active := false
var _authorized_next_open := false


func _ready() -> void:
	if locked and access_mode == AccessMode.UNLOCKED:
		access_mode = AccessMode.CARD_LOCKED
	_collect_slide_nodes()
	_apply_metadata_to_slides()
	_apply_open_distance_overrides()
	_connect_slide_signals()
	_apply_access_mode_state()
	_configure_group_indicator()
	set_process(synchronize_hover_highlight and _slide_nodes.size() > 1)


func _process(_delta: float) -> void:
	if not synchronize_hover_highlight or _slide_nodes.size() < 2:
		return

	var any_highlight := false
	var synced_visual_state := 0
	var source_slide: Node = null
	for slide in _slide_nodes:
		if slide == null or not is_instance_valid(slide):
			continue
		if slide.has_method("is_highlight_active_for_group") and bool(slide.call("is_highlight_active_for_group")):
			any_highlight = true
			source_slide = slide
			if slide.has_method("get_group_visual_state"):
				synced_visual_state = int(slide.call("get_group_visual_state"))
			break

	if any_highlight != _group_highlight_active:
		_group_highlight_active = any_highlight
		_apply_group_hover_highlight(any_highlight)
	_apply_group_visual_state(source_slide, synced_visual_state, any_highlight)


func set_locked(value: bool) -> void:
	locked = value
	access_mode = AccessMode.CARD_LOCKED if value else AccessMode.UNLOCKED
	_apply_access_mode_state()


func lock() -> void:
	locked = true
	access_mode = AccessMode.CARD_LOCKED
	_apply_access_mode_state()


func unlock() -> void:
	locked = false
	access_mode = AccessMode.UNLOCKED
	_apply_access_mode_state()


func disable() -> void:
	locked = true
	access_mode = AccessMode.DISABLED
	_apply_access_mode_state()


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


func _apply_access_mode_state() -> void:
	locked = access_mode != AccessMode.UNLOCKED
	var allow_locked_interaction := access_mode == AccessMode.CARD_LOCKED
	for slide in _slide_nodes:
		if slide != null and is_instance_valid(slide):
			slide.call("set_locked", locked)
			if slide.has_method("set_allow_interaction_when_locked"):
				slide.call("set_allow_interaction_when_locked", allow_locked_interaction)


func _apply_metadata_to_slides() -> void:
	var title_by_index := [door_title, door_title_secondary]
	for i in range(_slide_nodes.size()):
		var slide = _slide_nodes[i]
		if slide == null or not is_instance_valid(slide):
			continue
		if _object_has_property(slide, "privacy_glass_enabled"):
			slide.set("privacy_glass_enabled", privacy_glass_enabled)
		if _object_has_property(slide, "title_side"):
			slide.set("title_side", _resolve_title_side_for_slide(slide))
		if _object_has_property(slide, "door_title"):
			var assigned_title: String = str(title_by_index[i]) if i < title_by_index.size() else ""
			slide.set("door_title", assigned_title)
		if slide.has_method("apply_metadata_visuals"):
			slide.call("apply_metadata_visuals")


func _object_has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if str(property_info.name) == property_name:
			return true
	return false


func _resolve_title_side_for_slide(slide: Node) -> int:
	var resolved_side := title_side
	if slide is Node3D:
		var slide_node := slide as Node3D
		# door_slide2 is rotated/flipped relative to door_slide in the double-door scene.
		# Flip side selection so both leaf titles read correctly from the same corridor side.
		if slide_node.transform.basis.x.dot(Vector3.RIGHT) < 0.0:
			resolved_side = 1 - resolved_side
	return resolved_side


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


func _on_slide_open_requested(_source: Node, _actor: Node = null) -> void:
	return


func request_open_from_slide(source: Node, actor: Node = null) -> void:
	if access_mode == AccessMode.DISABLED:
		return
	if access_mode == AccessMode.UNLOCKED:
		_open_group()
		return
	if access_mode == AccessMode.CARD_LOCKED:
		if _authorized_next_open or _is_actor_inside(source, actor):
			_authorized_next_open = false
			_open_group()


func authorize_next_open() -> void:
	_authorized_next_open = true


func grant_access_and_open() -> void:
	if access_mode != AccessMode.CARD_LOCKED:
		return
	_authorized_next_open = true
	_open_group()


func _open_group() -> void:
	for slide in _slide_nodes:
		if slide != null and is_instance_valid(slide) and slide.has_method("force_open"):
			slide.call("force_open")


func _is_actor_inside(source: Node, actor: Node) -> bool:
	if source == null or actor == null:
		return false
	if not (source is Node3D) or not (actor is Node3D):
		return false
	var source_node := source as Node3D
	var actor_node := actor as Node3D
	var to_actor := actor_node.global_position - source_node.global_position
	if to_actor.length_squared() <= 0.0001:
		return false
	var forward := -source_node.global_transform.basis.z.normalized()
	return forward.dot(to_actor.normalized()) < 0.0


func _apply_group_hover_highlight(active: bool) -> void:
	for slide in _slide_nodes:
		if slide != null and is_instance_valid(slide) and slide.has_method("set_group_highlight"):
			slide.call("set_group_highlight", active)


func _apply_group_visual_state(source_slide: Node, state: int, active: bool) -> void:
	for slide in _slide_nodes:
		if slide == null or not is_instance_valid(slide):
			continue
		if slide == source_slide:
			if slide.has_method("clear_group_visual_state"):
				slide.call("clear_group_visual_state")
			continue
		if slide.has_method("apply_group_visual_state"):
			slide.call("apply_group_visual_state", state, active)


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
		if interactable != null and interactable.has_method("get_indicator_world_position"):
			midpoint += interactable.call("get_indicator_world_position")
		elif interactable != null and interactable.has_method("get_focus_position"):
			midpoint += interactable.call("get_focus_position")
	midpoint /= float(interactables.size())

	var primary = interactables[0]
	if primary != null and primary.has_method("set_indicator_visible"):
		primary.call("set_indicator_visible", true)
	if primary != null and primary.has_method("set_indicator_world_position_override"):
		primary.call("set_indicator_world_position_override", midpoint, true)

	for i in range(1, interactables.size()):
		var secondary = interactables[i]
		if secondary != null and secondary.has_method("set_indicator_visible"):
			secondary.call("set_indicator_visible", false)
		if secondary != null and secondary.has_method("set_indicator_world_position_override"):
			secondary.call("set_indicator_world_position_override", Vector3.ZERO, false)
