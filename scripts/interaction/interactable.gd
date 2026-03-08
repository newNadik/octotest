extends Area3D
class_name Interactable


signal interacted(interactable: Interactable, actor: Node)
signal clicked(interactable: Interactable, actor: Node)
signal picked_up(interactable: Interactable, actor: Node)
signal dropped(interactable: Interactable, actor: Node)

enum InteractionType {
	CLICK,
	PICKUP,
}

enum ItemKind {
	NONE,
	CARD,
}

enum VisualState {
	IDLE,
	HOVERED,
	IN_RANGE,
	BLOCKED,
	HELD,
}

@export var interaction_type: InteractionType = InteractionType.CLICK
@export var item_kind: ItemKind = ItemKind.NONE
@export var item_id := ""
@export var display_name := "Interactable"
@export var interaction_range := 2.6
@export var prompt_action := "Interact"
@export var focus_offset := Vector3.ZERO
@export var hold_offset := Vector3(0.0, -0.1, 0.35)
@export var hold_rotation_degrees := Vector3.ZERO
@export var visual_root_path: NodePath = NodePath("..")
@export var pickup_root_path: NodePath = NodePath("..")
@export var hover_color := Color(1.0, 0.83, 0.25, 0.55)
@export var in_range_color := Color(0.33, 0.95, 0.48, 0.48)
@export var blocked_color := Color(0.96, 0.3, 0.3, 0.6)

var _visual_root: Node3D
var _pickup_root: Node3D
var _mesh_nodes: Array[MeshInstance3D] = []
var _state_materials: Dictionary = {}
var _current_state: VisualState = VisualState.IDLE
var _saved_area_layer := 0
var _saved_area_mask := 0
var _saved_pickup_layer := 0
var _saved_pickup_mask := 0
var _has_saved_pickup_collision := false
var _interaction_enabled := true


func _ready() -> void:
	_visual_root = get_node_or_null(visual_root_path) as Node3D
	if _visual_root == null:
		_visual_root = get_parent() as Node3D

	_pickup_root = get_node_or_null(pickup_root_path) as Node3D
	if _pickup_root == null:
		_pickup_root = get_parent() as Node3D

	_collect_meshes(_visual_root)
	_build_materials()
	_saved_area_layer = collision_layer
	_saved_area_mask = collision_mask
	_set_visual_state(VisualState.IDLE)


func get_focus_position() -> Vector3:
	return _pickup_root.global_position + _pickup_root.global_basis * focus_offset


func can_interact_from(player_position: Vector3) -> bool:
	return player_position.distance_to(get_focus_position()) <= interaction_range


func get_hold_transform() -> Transform3D:
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(hold_rotation_degrees.x),
		deg_to_rad(hold_rotation_degrees.y),
		deg_to_rad(hold_rotation_degrees.z)
	))
	return Transform3D(basis, hold_offset)


func get_pickup_root() -> Node3D:
	return _pickup_root


func is_card() -> bool:
	return item_kind == ItemKind.CARD


func set_interaction_enabled(is_enabled: bool) -> void:
	_interaction_enabled = is_enabled
	if _interaction_enabled:
		collision_layer = _saved_area_layer
		collision_mask = _saved_area_mask
	else:
		collision_layer = 0
		collision_mask = 0


func interact(actor: Node) -> void:
	emit_signal("interacted", self, actor)
	if interaction_type == InteractionType.CLICK:
		emit_signal("clicked", self, actor)
	elif interaction_type == InteractionType.PICKUP:
		emit_signal("picked_up", self, actor)


func drop(actor: Node) -> void:
	if interaction_type == InteractionType.PICKUP:
		emit_signal("dropped", self, actor)


func set_held(is_held: bool) -> void:
	if is_held:
		_set_visual_state(VisualState.HELD)
	else:
		set_interaction_enabled(_interaction_enabled)
		_set_visual_state(VisualState.IDLE)

	if _pickup_root == null:
		return

	if _pickup_root is CollisionObject3D:
		var collision := _pickup_root as CollisionObject3D
		if not _has_saved_pickup_collision:
			_saved_pickup_layer = collision.collision_layer
			_saved_pickup_mask = collision.collision_mask
			_has_saved_pickup_collision = true

		if is_held:
			collision.collision_layer = 0
			collision.collision_mask = 0
		else:
			collision.collision_layer = _saved_pickup_layer
			collision.collision_mask = _saved_pickup_mask

	if _pickup_root is RigidBody3D:
		var body := _pickup_root as RigidBody3D
		body.freeze = is_held
		if is_held:
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO


func set_visual_state(state: VisualState) -> void:
	_set_visual_state(state)


func _set_visual_state(state: VisualState) -> void:
	if _current_state == state:
		return

	_current_state = state
	var overlay_material: Material = null
	match state:
		VisualState.HOVERED:
			overlay_material = _state_materials.get("hover")
		VisualState.IN_RANGE:
			overlay_material = _state_materials.get("in_range")
		VisualState.BLOCKED:
			overlay_material = _state_materials.get("blocked")
		_:
			overlay_material = null

	for mesh in _mesh_nodes:
		mesh.material_overlay = overlay_material


func _collect_meshes(node: Node) -> void:
	if node == null:
		return

	if node is MeshInstance3D:
		_mesh_nodes.append(node as MeshInstance3D)

	for child: Node in node.get_children():
		_collect_meshes(child)


func _build_materials() -> void:
	_state_materials["hover"] = _make_overlay_material(hover_color)
	_state_materials["in_range"] = _make_overlay_material(in_range_color)
	_state_materials["blocked"] = _make_overlay_material(blocked_color)


func _make_overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = false
	return material
