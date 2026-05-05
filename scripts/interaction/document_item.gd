@tool
extends StaticBody3D
class_name DocumentItem

enum DocumentSize {
	A4_PORTRAIT,
	A1_LANDSCAPE,
}

const PAGE_FLIP_SOUND := preload("res://assets/sound/page_flip.wav")
const A4_SIZE := Vector2(0.756, 1.069)
const A1_LANDSCAPE_SIZE := Vector2(3.0, 2.1)

@export var document_size: DocumentSize = DocumentSize.A4_PORTRAIT
@export var document_texture: Texture2D
@export var document_texture_ua: Texture2D
@export var interactable_enabled := true
@export_range(-180.0, 180.0, 0.1) var focus_roll_offset_degrees := 0.0
@export_group("Visual")
@export_range(0.0, 1.0, 0.01) var paper_roughness := 0.92
@export_range(0.0, 1.0, 0.01) var paper_specular := 0.04
@export_range(0.5, 1.5, 0.01) var paper_brightness := 0.9
@export_group("")

@onready var _mesh: MeshInstance3D = $DocumentMesh
@onready var _body_collision: CollisionShape3D = $CollisionShape3D
@onready var _area_collision: CollisionShape3D = $Interactable/CollisionShape3D
@onready var _interactable: Area3D = $Interactable
@onready var _focus_target: FocusTarget = $FocusTarget
@onready var _outline_mesh: MeshInstance3D = get_node_or_null("DocumentMesh/OutlineMesh") as MeshInstance3D
var _focus_active_last_frame := false
var _interactable_enabled_last_frame := true
var _locale_last_frame := ""
var _outline_base_scale := Vector3.ONE
var _preview_signature := ""
var _page_flip_player: AudioStreamPlayer3D


func _ready() -> void:
	_mesh.mesh = _mesh.mesh.duplicate()
	_body_collision.shape = _body_collision.shape.duplicate()
	_area_collision.shape = _area_collision.shape.duplicate()
	if _outline_mesh != null:
		_outline_base_scale = _outline_mesh.scale
	_apply_document_size()
	_apply_texture()
	_setup_focus_angles()
	_interactable_enabled_last_frame = not interactable_enabled
	_apply_interactable_enabled_state()
	_locale_last_frame = TranslationServer.get_locale()
	_setup_page_flip_player()
	# Force first _process() reconciliation so interaction state is corrected
	# after load even if it was persisted while focused.
	_focus_active_last_frame = not _is_focus_active()
	_preview_signature = _build_preview_signature()
	set_process(true)


func _process(_delta: float) -> void:
	_update_interactable_enabled_if_needed()
	if not interactable_enabled:
		_enforce_non_interactable_visuals()
	if Engine.is_editor_hint():
		_update_editor_preview_if_needed()
		return
	_update_texture_for_locale_if_needed()
	_update_focus_interaction_state()


func _apply_document_size() -> void:
	var size := _get_document_size()
	(_mesh.mesh as QuadMesh).size = size
	(_body_collision.shape as BoxShape3D).size = Vector3(size.x, size.y, 0.01)
	(_area_collision.shape as BoxShape3D).size = Vector3(size.x + 0.1, size.y + 0.1, 0.3)
	_apply_outline_size(size)
	var margin := minf(size.x, size.y) * 0.08
	_interactable.indicator_local_offset = Vector3(size.x * 0.5 - margin, -size.y * 0.5 + margin, 0.02)


func _apply_texture() -> void:
	var texture_to_use := _get_texture_for_locale()
	if texture_to_use == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture_to_use
	mat.albedo_color = Color(paper_brightness, paper_brightness, paper_brightness, 1.0)
	mat.roughness = paper_roughness
	mat.specular = paper_specular
	mat.metallic = 0.0
	mat.emission_enabled = false
	_mesh.material_override = mat


func _get_texture_for_locale() -> Texture2D:
	var locale := TranslationServer.get_locale()
	if locale.begins_with("uk") and document_texture_ua != null:
		return document_texture_ua
	return document_texture


func _setup_focus_angles() -> void:
	var doc_up := global_basis.y.normalized()
	var n := _compute_best_focus_normal(global_basis.z.normalized(), doc_up)
	var yaw_degrees := rad_to_deg(atan2(n.x, n.z))
	var pitch_degrees := rad_to_deg(asin(clampf(-n.y, -1.0, 1.0)))
	_focus_target.use_angle_override = true
	_focus_target.focus_yaw_degrees = yaw_degrees
	_focus_target.focus_pitch_degrees = pitch_degrees
	_focus_target.focus_roll_degrees = _compute_focus_roll_degrees(yaw_degrees, pitch_degrees, n, doc_up) + focus_roll_offset_degrees

	var size := _get_document_size()
	var zoom_start := _compute_zoom_start(size.y)
	_focus_target.focus_zoom_start = zoom_start
	_focus_target.focus_min_zoom = maxf(0.2, zoom_start * 0.2)
	_focus_target.focus_max_zoom = zoom_start * 2.0
	_focus_target.focus_zoom_step = zoom_start * 0.08


func _compute_best_focus_normal(doc_normal: Vector3, doc_up: Vector3) -> Vector3:
	var forward_a := doc_normal
	var forward_b := -doc_normal
	var score_a := _compute_focus_up_alignment_score(forward_a, doc_up)
	var score_b := _compute_focus_up_alignment_score(forward_b, doc_up)
	return forward_a if score_a >= score_b else forward_b


func _compute_focus_up_alignment_score(forward: Vector3, doc_up: Vector3) -> float:
	var world_up := Vector3.UP
	var right := world_up.cross(forward)
	if right.length_squared() <= 0.000001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var camera_up := forward.cross(right).normalized()
	return camera_up.dot(doc_up)


func _compute_focus_roll_degrees(yaw_degrees: float, pitch_degrees: float, forward: Vector3, doc_up: Vector3) -> float:
	# Match the same rotation composition as camera rig:
	# CameraPivot/CameraYaw (Y) -> CameraPitch (X), with zero roll.
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var pitch_basis := Basis(Vector3.RIGHT, deg_to_rad(pitch_degrees))
	var base_basis := yaw_basis * pitch_basis
	var base_camera_up := base_basis.y.normalized()

	var doc_up_planar := doc_up - forward * doc_up.dot(forward)
	if doc_up_planar.length_squared() <= 0.000001:
		return 0.0
	doc_up_planar = doc_up_planar.normalized()
	var base_up_planar := base_camera_up - forward * base_camera_up.dot(forward)
	if base_up_planar.length_squared() <= 0.000001:
		return 0.0
	base_up_planar = base_up_planar.normalized()

	var sinv := forward.dot(base_up_planar.cross(doc_up_planar))
	var cosv := clampf(base_up_planar.dot(doc_up_planar), -1.0, 1.0)
	return rad_to_deg(atan2(sinv, cosv))


func _compute_zoom_start(doc_height: float) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return 1.2
	var vfov_rad := deg_to_rad(camera.fov)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		var vp := get_viewport().get_visible_rect().size
		if vp.x > 0.0:
			vfov_rad = 2.0 * atan(tan(vfov_rad * 0.5) * vp.y / vp.x)
	return (doc_height * 0.5 / tan(vfov_rad * 0.5)) / 0.9


func _get_document_size() -> Vector2:
	return A4_SIZE if document_size == DocumentSize.A4_PORTRAIT else A1_LANDSCAPE_SIZE


func _apply_outline_size(size: Vector2) -> void:
	if _outline_mesh == null:
		return
	var width_ratio := size.x / A4_SIZE.x
	var height_ratio := size.y / A4_SIZE.y
	_outline_mesh.scale = Vector3(
		_outline_base_scale.x * width_ratio,
		_outline_base_scale.y * height_ratio,
		_outline_base_scale.z
	)


func _update_texture_for_locale_if_needed() -> void:
	var locale_now := TranslationServer.get_locale()
	if locale_now == _locale_last_frame:
		return
	_locale_last_frame = locale_now
	_apply_texture()


func _update_focus_interaction_state() -> void:
	var focus_active := _is_focus_active()
	if focus_active == _focus_active_last_frame:
		return
	_focus_active_last_frame = focus_active
	_set_interactable_enabled(interactable_enabled and not focus_active)
	if focus_active:
		_set_interactable_idle_visual()
		_play_page_flip()


func _update_interactable_enabled_if_needed() -> void:
	if interactable_enabled == _interactable_enabled_last_frame:
		return
	_interactable_enabled_last_frame = interactable_enabled
	_apply_interactable_enabled_state()


func _apply_interactable_enabled_state() -> void:
	_set_interactable_indicator_visible(interactable_enabled)
	_set_interactable_enabled(interactable_enabled and not _is_focus_active())
	if not interactable_enabled:
		_enforce_non_interactable_visuals()


func _enforce_non_interactable_visuals() -> void:
	_set_interactable_indicator_visible(false)
	_set_interactable_enabled(false)
	_set_interactable_idle_visual()
	if _outline_mesh != null:
		_outline_mesh.visible = false


func _set_interactable_indicator_visible(is_visible: bool) -> void:
	if _interactable == null:
		return
	if Engine.is_editor_hint():
		return
	if _interactable.has_method("set_indicator_visible"):
		_interactable.call("set_indicator_visible", is_visible)
	elif "show_indicator" in _interactable:
		_interactable.set("show_indicator", is_visible)


func _set_interactable_enabled(is_enabled: bool) -> void:
	if _interactable == null:
		return
	if Engine.is_editor_hint():
		_interactable.collision_layer = 8 if is_enabled else 0
		_interactable.collision_mask = 0
		return
	if _interactable.has_method("set_interaction_enabled"):
		_interactable.call("set_interaction_enabled", is_enabled)
		return
	_interactable.collision_layer = 8 if is_enabled else 0
	_interactable.collision_mask = 0


func _set_interactable_idle_visual() -> void:
	if _interactable == null:
		return
	if Engine.is_editor_hint():
		return
	if _interactable.has_method("set_visual_state"):
		_interactable.call("set_visual_state", Interactable.VisualState.IDLE)


func _update_editor_preview_if_needed() -> void:
	var signature := _build_preview_signature()
	if signature == _preview_signature:
		return
	_preview_signature = signature
	_apply_document_size()
	_apply_texture()
	_setup_focus_angles()


func _build_preview_signature() -> String:
	return "%d|%s|%s|%s|%s|%s|%s|%s" % [
		int(document_size),
		str(document_texture),
		str(document_texture_ua),
		TranslationServer.get_locale(),
		str(focus_roll_offset_degrees),
		str(paper_roughness),
		str(paper_specular),
		str(paper_brightness)
	]


func _is_focus_active() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if not scene.has_method("is_focus_target_active"):
		return false
	return bool(scene.call("is_focus_target_active", _focus_target))


func _setup_page_flip_player() -> void:
	_page_flip_player = AudioStreamPlayer3D.new()
	_page_flip_player.stream = PAGE_FLIP_SOUND
	_page_flip_player.volume_db = -7.0
	_page_flip_player.max_distance = 16.0
	_page_flip_player.unit_size = 1.0
	add_child(_page_flip_player)


func _play_page_flip() -> void:
	if _page_flip_player == null:
		return
	_page_flip_player.pitch_scale = randf_range(0.96, 1.04)
	_page_flip_player.play()
