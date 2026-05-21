extends Node3D

@export var interactable_path: NodePath = NodePath("Interactable")
@export var armature_path: NodePath = NodePath("Node3D/Armature")
@export var spring_simulator_path: NodePath = NodePath("Node3D/Armature/Skeleton3D/SpringBoneSimulator3D")
@export var floor_collision_path: NodePath = NodePath("Node3D/Armature/Skeleton3D/SpringBoneSimulator3D/FloorCollision")
@export var octo_collision_sphere_path: NodePath = NodePath("Node3D/Armature/Skeleton3D/SpringBoneSimulator3D/OctoCollisionSphere3D")
@export var floor_drop_delay := 0.0
@export var pickup_sfx_volume_db := -6.0
@export var drop_sfx_volume_db := -6.0
@export var debug_show_spring_collisions := true
@export var debug_plane_size := Vector2(20.0, 20.0)
@export var debug_color := Color(0.2, 0.9, 1.0, 0.28)

const PICKUP_SFX := preload("res://assets/sound/measuring-tape-on.mp3")
const DROP_SFX := preload("res://assets/sound/measuring-tape-off.mp3")

var _interactable: Interactable
var _armature: Node3D
var _spring_simulator: SpringBoneSimulator3D
var _floor_collision: Node3D
var _octo_collision_sphere: Node3D
var _player: Node3D
var _main_scene: Node
var _sfx_player: AudioStreamPlayer3D
var _debug_floor_mesh: MeshInstance3D
var _debug_sphere_mesh: MeshInstance3D
var _is_held := false
var _drop_delay_left := 0.0

const FLOOR_DISABLED_LOCAL_POSITION := Vector3(0.0, -1000.0, 0.0)
const FLOOR_ACTIVE_HELD_POSITION := Vector3(0.0, -2.0, 0.0)
const FLOOR_ACTIVE_DROPPED_POSITION := Vector3(0.0, -3.0, 0.0)


func _ready() -> void:
	_armature = get_node_or_null(armature_path) as Node3D
	if _armature != null:
		_armature.visible = false

	_spring_simulator = get_node_or_null(spring_simulator_path) as SpringBoneSimulator3D
	_floor_collision = get_node_or_null(floor_collision_path) as Node3D
	_octo_collision_sphere = get_node_or_null(octo_collision_sphere_path) as Node3D
	_main_scene = get_tree().current_scene
	if _main_scene != null:
		_player = _main_scene.get_node_or_null("Player") as Node3D
	_ensure_sfx_player()
	_build_debug_collision_meshes()

	_interactable = get_node_or_null(interactable_path) as Interactable
	if _interactable == null:
		return

	if _interactable.has_signal("picked_up") and not _interactable.picked_up.is_connected(_on_picked_up):
		_interactable.picked_up.connect(_on_picked_up)
	if _interactable.has_signal("dropped") and not _interactable.dropped.is_connected(_on_dropped):
		_interactable.dropped.connect(_on_dropped)

	_update_floor_collision_state()


func _process(delta: float) -> void:
	if _drop_delay_left > 0.0:
		_drop_delay_left = maxf(0.0, _drop_delay_left - delta)
	_update_floor_collision_state()
	_update_octo_collision_sphere_state()
	_update_debug_collision_meshes()


func _on_picked_up(_interactable_ref, _actor) -> void:
	if _armature != null:
		_armature.visible = true
	_is_held = true
	_play_sfx(PICKUP_SFX, pickup_sfx_volume_db)


func _on_dropped(_interactable_ref, _actor) -> void:
	if _armature != null:
		_armature.visible = false
	_is_held = false
	_drop_delay_left = floor_drop_delay
	_play_sfx(DROP_SFX, drop_sfx_volume_db)


func _update_floor_collision_state() -> void:
	if _floor_collision == null:
		return

	var focus_active := false
	if _main_scene != null and _main_scene.has_method("is_focus_mode_active"):
		focus_active = bool(_main_scene.call("is_focus_mode_active"))

	if focus_active:
		_floor_collision.global_position = FLOOR_DISABLED_LOCAL_POSITION
	elif _is_held or _drop_delay_left > 0.0:
		_floor_collision.global_position = FLOOR_ACTIVE_HELD_POSITION
	else:
		_floor_collision.global_position = FLOOR_ACTIVE_DROPPED_POSITION


func _update_octo_collision_sphere_state() -> void:
	if _octo_collision_sphere == null:
		return
	if _player == null and _main_scene != null:
		_player = _main_scene.get_node_or_null("Player") as Node3D
	if _player == null:
		return
	_octo_collision_sphere.global_position = _player.global_position


func _build_debug_collision_meshes() -> void:
	if not debug_show_spring_collisions:
		return
	var debug_material := StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.albedo_color = debug_color
	debug_material.no_depth_test = true

	if _floor_collision != null:
		_debug_floor_mesh = MeshInstance3D.new()
		_debug_floor_mesh.name = "DebugFloorCollisionMesh"
		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = debug_plane_size
		_debug_floor_mesh.mesh = plane_mesh
		_debug_floor_mesh.material_override = debug_material
		add_child(_debug_floor_mesh)

	if _octo_collision_sphere != null:
		_debug_sphere_mesh = MeshInstance3D.new()
		_debug_sphere_mesh.name = "DebugOctoCollisionSphereMesh"
		var sphere_mesh := SphereMesh.new()
		var radius := float(_octo_collision_sphere.get("radius"))
		sphere_mesh.radius = maxf(0.001, radius)
		sphere_mesh.height = maxf(0.001, radius * 2.0)
		_debug_sphere_mesh.mesh = sphere_mesh
		_debug_sphere_mesh.material_override = debug_material
		add_child(_debug_sphere_mesh)


func _update_debug_collision_meshes() -> void:
	if _debug_floor_mesh != null and _floor_collision != null:
		_debug_floor_mesh.global_transform = _floor_collision.global_transform
	if _debug_sphere_mesh != null and _octo_collision_sphere != null:
		_debug_sphere_mesh.global_transform = _octo_collision_sphere.global_transform


func _ensure_sfx_player() -> void:
	if _sfx_player != null:
		return
	_sfx_player = AudioStreamPlayer3D.new()
	_sfx_player.name = "TapeSfxPlayer3D"
	_sfx_player.max_distance = 24.0
	_sfx_player.unit_size = 4.0
	add_child(_sfx_player)


func _play_sfx(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	if _sfx_player == null:
		_ensure_sfx_player()
	if _sfx_player == null:
		return
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()
