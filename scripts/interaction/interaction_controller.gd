extends Node
class_name InteractionController


const WALL_COLLISION_MASK := 1 << 0
const INTERACTABLE_COLLISION_MASK := 1 << 3
const CardReaderScript = preload("res://scripts/interaction/card_reader.gd")
const CodePanelScript = preload("res://scripts/interaction/code_panel.gd")
const FocusTargetScript = preload("res://scripts/interaction/focus_target.gd")
const FocusRejectFeedbackScript = preload("res://scripts/interaction/focus_reject_feedback.gd")
const InteractableScript = preload("res://scripts/interaction/interactable.gd")
const InteractionHintBuilderScript = preload("res://scripts/interaction/interaction_hint_builder.gd")
const OctoRigScript = preload("res://scripts/rig/OctoRig.gd")
const FOCUS_SELECTION_CLICK_RADIUS := 220.0
const FOCUS_HELD_CLICK_RADIUS := 170.0
const FOCUS_READER_INSERTED_CLICK_RADIUS := 190.0
const FALLBACK_HOLD_ARM_PRIORITY := ["arm_2", "arm_3", "arm_5", "arm_4", "arm_0", "arm_1", "arm_6", "arm_7"]
const ARM_SOCKET_ANGLE_BY_NAME := {
	"arm_0": 2.36,   # left front
	"arm_1": 0.78,   # right front
	"arm_2": 2.62,   # left front-mid
	"arm_3": 0.52,   # right front-mid
	"arm_4": -0.52,  # right back-mid
	"arm_5": -2.62,  # left back-mid
	"arm_6": -2.36,  # left back
	"arm_7": -0.78,  # right back
}

@export var interact_move_standoff = 1.2
@export var held_item_follow_speed = 15.0
@export var max_held_items = 8
@export var slow_at_item_count = 5
@export var immobilized_at_item_count = 8
@export var heavy_carry_speed_multiplier = 0.45
@export var hand_socket_inner_radius = 0.3
@export var hand_socket_outer_radius = 0.54
@export var hand_socket_height = 0.34
@export var held_item_min_world_height = 0.46
@export var held_item_clearance_max = 0.62
@export var drop_clamp_extent = 15.2
@export var debug_interaction_logs = false
@export var focus_reject_feedback_duration = 0.32

var _player: CharacterBody3D
var _camera: Camera3D
var _hint_label: Label
var _world_root: Node3D
var _room_light: OmniLight3D

var _interaction_enabled = true
var _hovered_interactable
var _hovered_in_range = false
var _hovered_blocked = false
var _held_interactables: Array = []
var _hand_sockets: Array[Node3D] = []
var _held_socket_by_item_id: Dictionary = {}
var _held_global_scale_by_item_id: Dictionary = {}
var _held_clearance_by_item_id: Dictionary = {}
var _socket_index_by_arm_name: Dictionary = {}
var _arm_name_by_socket_index: Dictionary = {}
var _queued_interaction_target
var _pending_card_reader: CardReaderScript
var _awaiting_card_selection = false
var _eligible_held_cards: Array = []
var _light_toggle_on = true
var _default_light_energy = 4.0
var _base_move_speed = 6.0
var _focus_locked = false
var _focus_display_enabled = false
var _focus_display_camera: Camera3D
var _focus_target: FocusTargetScript
var _focus_card_reader: CardReaderScript
var _focus_reject_feedback = FocusRejectFeedbackScript.new()
var _hint_builder = InteractionHintBuilderScript.new()
var _octo_rig: OctoRigScript


func initialize(player: CharacterBody3D, camera: Camera3D, hint_label: Label, world_root: Node3D, room_light: OmniLight3D) -> void:
	_player = player
	_camera = camera
	_hint_label = hint_label
	_world_root = world_root
	_room_light = room_light
	_base_move_speed = _player.move_speed
	_default_light_energy = _room_light.light_energy
	_focus_reject_feedback.duration = focus_reject_feedback_duration
	_ensure_hand_sockets()
	_resolve_octo_rig()
	_configure_hold_arm_slot_mapping()
	_setup_scene_interactables()
	_update_carry_mobility()
	_update_hint_text()


func set_interaction_enabled(is_enabled: bool) -> void:
	if _interaction_enabled == is_enabled:
		return
	_interaction_enabled = is_enabled
	if not _interaction_enabled:
		_cancel_card_selection_mode()
		_set_hovered_interactable(null, false, false)


func process_interactions(delta: float) -> void:
	if not _interaction_enabled:
		return
	_process_queued_interaction()
	_update_hovered_interactable()
	_update_held_item_transform(delta)


func consume_escape() -> bool:
	if _awaiting_card_selection:
		_cancel_card_selection_mode()
		return true
	return false


func try_handle_interaction_click(screen_position: Vector2) -> bool:
	if not _interaction_enabled:
		_debug_log("Ignored click: interaction disabled")
		return false

	var target = _raycast_to_interactable(screen_position)
	_debug_log("Click at %s target=%s focus_locked=%s awaiting_card_selection=%s" % [
		str(screen_position),
		_describe_interactable(target),
		str(_focus_locked),
		str(_awaiting_card_selection),
	])

	if _awaiting_card_selection:
		if target == null and _focus_locked:
			var clicked_card = _get_eligible_card_at_screen(screen_position, FOCUS_SELECTION_CLICK_RADIUS)
			if clicked_card != null and _is_click_confirmed_for_held_item(clicked_card):
				_debug_log("Card selection: screen-picked %s" % _describe_interactable(clicked_card))
				_apply_card_to_pending_reader(clicked_card)
				return true
			var clicked_held = _get_held_item_at_screen(screen_position, FOCUS_SELECTION_CLICK_RADIUS)
			if clicked_held != null and _is_click_confirmed_for_held_item(clicked_held) and _focus_card_reader != null and not _eligible_held_cards.has(clicked_held):
				_debug_log("Card selection: non-eligible item clicked %s" % _describe_interactable(clicked_held))
				_trigger_focus_reject_feedback(clicked_held)
				return true
		if target != null and _is_item_currently_held(target) and _eligible_held_cards.has(target):
			_debug_log("Card selection: ray-picked %s" % _describe_interactable(target))
			_apply_card_to_pending_reader(target)
			return true
		if target != null and _is_item_currently_held(target) and not _eligible_held_cards.has(target) and _focus_card_reader != null:
			_debug_log("Card selection: non-eligible ray item clicked %s" % _describe_interactable(target))
			_trigger_focus_reject_feedback(target)
			return true
		if target != null and _get_card_reader_for_interactable(target) == _pending_card_reader:
			_debug_log("Card selection cancelled by clicking reader")
			_cancel_card_selection_mode()
			return true
		if _focus_locked:
			var near_reader = _is_click_near_focus_card_reader(screen_position)
			var over_focus_items = is_click_over_focus_items(screen_position, FOCUS_SELECTION_CLICK_RADIUS)
			if near_reader or over_focus_items:
				_debug_log("Card selection pending: click inside focus interaction area")
				_update_hint_text()
				return true
			_debug_log("Card selection pending: outside click, allowing focus exit")
			return false
		_debug_log("Card selection pending: click did not resolve to eligible card")
		_update_hint_text()
		return true

	if target == null:
		if _focus_locked:
			var clicked_held = _get_held_item_at_screen(screen_position, FOCUS_HELD_CLICK_RADIUS)
			if clicked_held != null and _is_click_confirmed_for_held_item(clicked_held):
				_queued_interaction_target = null
				_try_apply_focus_held_item(clicked_held)
				_update_hint_text()
				return true
		_queued_interaction_target = null
		_debug_log("World click miss")
		return false

	if _is_item_currently_held(target):
		_queued_interaction_target = null
		if _focus_locked:
			_try_apply_focus_held_item(target)
			_update_hint_text()
			return true
		_debug_log("Dropping held item %s" % _describe_interactable(target))
		_drop_specific_held_item(target)
		return true

	var in_range = _is_interactable_in_range(target)
	var blocked = not _has_line_of_sight(target)
	if _is_focus_reader_interactable(target):
		in_range = true
		blocked = false
	if target.interaction_type == InteractableScript.InteractionType.PICKUP and _held_interactables.size() >= max_held_items:
		blocked = true
		in_range = false

	_set_hovered_interactable(target, in_range, blocked)
	if _hovered_blocked:
		return true

	if _hovered_in_range:
		_queued_interaction_target = null
		var reader = _get_card_reader_for_interactable(target)
		if reader != null:
			_debug_log("Reader interaction click on %s" % _describe_interactable(target))
			_handle_card_reader_click(reader)
			return true
		if target.interaction_type == InteractableScript.InteractionType.CLICK:
			target.interact(_player)
			return true
		if target.interaction_type == InteractableScript.InteractionType.PICKUP:
			_pick_up_interactable(target)
			return true
		return true

	if _is_movement_blocked_by_full_load():
		_trigger_blocked_move_feedback()
		return true

	_queued_interaction_target = target
	_debug_log("Queued move-to-interact for %s" % _describe_interactable(target))
	_move_toward_interactable(target)
	return true


func handle_drop_input(drop_all: bool) -> void:
	if _focus_locked:
		return
	if drop_all:
		_drop_all_held_items()
	else:
		_drop_last_held_item()


func try_interact_with_focus_target(screen_position := Vector2.INF) -> bool:
	if not _focus_locked or _focus_card_reader == null:
		_debug_log("Focus-target interact ignored: no focus reader")
		return false
	if screen_position.is_finite() and not _is_click_near_focus_card_reader(screen_position):
		_debug_log("Focus-target interact ignored: click not near reader")
		return false
	_debug_log("Focus-target interact accepted")
	_handle_card_reader_click(_focus_card_reader)
	return true


func is_click_over_focus_items(screen_position: Vector2, max_distance_px := 110.0) -> bool:
	if not _focus_display_enabled or _focus_display_camera == null:
		return false
	return _get_held_item_at_screen(screen_position, max_distance_px) != null


func _is_click_near_focus_card_reader(screen_position: Vector2) -> bool:
	if _focus_display_camera == null:
		return false
	if _focus_target != null:
		var focus_screen = _focus_display_camera.unproject_position(_focus_target.get_focus_position())
		if focus_screen.distance_to(screen_position) <= _focus_target.click_outside_exit_px:
			return true
	if _focus_card_reader.has_inserted_card():
		var inserted_screen = _focus_display_camera.unproject_position(_focus_card_reader.get_inserted_card_position())
		if inserted_screen.distance_to(screen_position) <= FOCUS_READER_INSERTED_CLICK_RADIUS:
			return true
	return false


func _get_held_item_at_screen(screen_position: Vector2, max_distance_px: float) :
	if not _focus_display_enabled or _focus_display_camera == null:
		return null
	var closest
	var best_distance = max_distance_px
	for held_item in _held_interactables:
		var pickup_root = held_item.get_pickup_root()
		if pickup_root == null:
			continue
		var item_screen = _focus_display_camera.unproject_position(pickup_root.global_position)
		var distance = item_screen.distance_to(screen_position)
		if distance <= best_distance:
			best_distance = distance
			closest = held_item
	return closest


func _get_eligible_card_at_screen(screen_position: Vector2, max_distance_px: float) :
	if not _focus_display_enabled or _focus_display_camera == null:
		return null
	var closest
	var best_distance = max_distance_px
	for card in _eligible_held_cards:
		if card == null or not is_instance_valid(card):
			continue
		var pickup_root = card.get_pickup_root()
		if pickup_root == null:
			continue
		var item_screen = _focus_display_camera.unproject_position(pickup_root.global_position)
		var distance = item_screen.distance_to(screen_position)
		if distance <= best_distance:
			best_distance = distance
			closest = card
	return closest


func _is_click_confirmed_for_held_item(item) -> bool:
	if item == null:
		return false
	if _hovered_interactable == null:
		return false
	return _hovered_interactable == item


func set_focus_locked(is_locked: bool) -> void:
	_focus_locked = is_locked
	_update_carry_mobility()


func set_held_item_visuals_visible(is_visible: bool) -> void:
	for held_item in _held_interactables:
		var root = held_item.get_pickup_root()
		if root != null:
			root.visible = is_visible


func set_focus_display(enabled: bool, camera: Camera3D = null) -> void:
	_focus_display_enabled = enabled
	_focus_display_camera = camera


func set_focus_target(target: FocusTargetScript) -> void:
	_focus_target = target
	_focus_card_reader = null
	_focus_reject_feedback.reset()
	if _focus_target == null:
		return
	var interactable = _get_interactable_for_focus_target(_focus_target)
	_focus_card_reader = _get_card_reader_for_interactable(interactable)


func get_held_item_names() -> PackedStringArray:
	var names = PackedStringArray()
	for held_item in _held_interactables:
		names.append(held_item.display_name)
	return names


func get_held_items_for_focus() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for held_item in _held_interactables:
		var eligible = true
		if _awaiting_card_selection:
			eligible = _eligible_held_cards.has(held_item)
		items.append({
			"name": held_item.display_name,
			"eligible": eligible,
		})
	return items


func select_held_item_by_index(index: int) -> bool:
	if index < 0 or index >= _held_interactables.size():
		return false
	if not _awaiting_card_selection:
		return false

	var item = _held_interactables[index]
	if not _eligible_held_cards.has(item):
		return false

	_apply_card_to_pending_reader(item)
	return true


func is_awaiting_card_selection() -> bool:
	return _awaiting_card_selection


func get_focus_target_at_screen(screen_position: Vector2) -> FocusTargetScript:
	var target = _raycast_to_interactable(screen_position)
	return _get_focus_target_for_interactable(target)


func request_approach_focus_target(focus_target: FocusTargetScript) -> void:
	var interactable = _get_interactable_for_focus_target(focus_target)
	if interactable != null:
		if _is_movement_blocked_by_full_load():
			_trigger_blocked_move_feedback()
			return
		_move_toward_interactable(interactable)


func try_handle_ground_move_click() -> bool:
	if not _is_movement_blocked_by_full_load():
		return false
	_trigger_blocked_move_feedback()
	return true


func can_enter_focus_target(focus_target: FocusTargetScript) -> bool:
	if focus_target == null:
		return false
	var interactable = _get_interactable_for_focus_target(focus_target)
	if interactable == null:
		return false
	if not _is_interactable_in_range(interactable):
		return false
	if not _has_line_of_sight(interactable):
		return false
	var planar_speed = Vector2(_player.velocity.x, _player.velocity.z).length()
	return planar_speed <= 0.12


func is_focus_target_solved(focus_target: FocusTargetScript) -> bool:
	if focus_target == null:
		return false
	return focus_target.is_solved()


func _raycast_to_interactable(screen_position: Vector2) :
	var from = _camera.project_ray_origin(screen_position)
	var to = from + _camera.project_ray_normal(screen_position) * 500.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = INTERACTABLE_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [_player]

	var result = _world_root.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	if result.collider is Area3D:
		return result.collider
	return null


func _get_focus_target_for_interactable(target) -> FocusTargetScript:
	if target == null:
		return null
	var parent = target.get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is FocusTargetScript:
			return child as FocusTargetScript
	return null


func _get_interactable_for_focus_target(focus_target: FocusTargetScript) :
	if focus_target == null:
		return null
	var host = focus_target.get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Interactable")


func _process_queued_interaction() -> void:
	if _queued_interaction_target == null:
		return
	if not is_instance_valid(_queued_interaction_target):
		_queued_interaction_target = null
		return
	if _is_item_currently_held(_queued_interaction_target):
		_queued_interaction_target = null
		return
	if not _has_line_of_sight(_queued_interaction_target):
		return
	if not _is_interactable_in_range(_queued_interaction_target):
		return

	if _queued_interaction_target.interaction_type == InteractableScript.InteractionType.PICKUP:
		if _held_interactables.size() >= max_held_items:
			_queued_interaction_target = null
			return
		_pick_up_interactable(_queued_interaction_target)
		_queued_interaction_target = null
		return

	if _queued_interaction_target.interaction_type == InteractableScript.InteractionType.CLICK:
		var reader = _get_card_reader_for_interactable(_queued_interaction_target)
		if reader != null:
			_handle_card_reader_click(reader)
			_queued_interaction_target = null
			return
		_queued_interaction_target.interact(_player)
		_queued_interaction_target = null


func _update_hovered_interactable() -> void:
	var target = _raycast_to_interactable(get_viewport().get_mouse_position())
	if target == null:
		_set_hovered_interactable(null, false, false)
		return

	if _is_item_currently_held(target):
		_set_hovered_interactable(target, true, false)
		return

	var in_range = _is_interactable_in_range(target)
	var blocked = not _has_line_of_sight(target)
	if _is_focus_reader_interactable(target):
		in_range = true
		blocked = false
	if target.interaction_type == InteractableScript.InteractionType.PICKUP and _held_interactables.size() >= max_held_items:
		blocked = true
		in_range = false

	_set_hovered_interactable(target, in_range, blocked)


func _get_card_reader_for_interactable(target) -> CardReaderScript:
	if target == null:
		return null
	var node = target.get_parent()
	while node != null:
		if node is CardReaderScript:
			return node as CardReaderScript
		node = node.get_parent()
	return null


func _is_focus_reader_interactable(target) -> bool:
	if not _focus_locked or _focus_card_reader == null or target == null:
		return false
	return _get_card_reader_for_interactable(target) == _focus_card_reader


func _handle_card_reader_click(reader: CardReaderScript) -> void:
	if reader == null:
		return

	if reader.has_inserted_card():
		_debug_log("Reader has inserted card; attempting eject")
		if _held_interactables.size() >= max_held_items:
			_debug_log("Eject blocked: hands are full")
			_update_hint_text()
			return
		var ejected_card = reader.eject_card()
		if ejected_card != null:
			_debug_log("Ejected card %s" % _describe_interactable(ejected_card))
			_attach_item_to_hands(ejected_card, false)
		_cancel_card_selection_mode()
		_update_hint_text()
		return

	var held_cards = _get_held_cards()
	if held_cards.is_empty():
		_debug_log("Reader empty and no held cards")
		_cancel_card_selection_mode()
		_update_hint_text()
		return

	if held_cards.size() == 1:
		_debug_log("Reader empty; single held card %s" % _describe_interactable(held_cards[0]))
		_pending_card_reader = reader
		_apply_card_to_pending_reader(held_cards[0])
		return

	_debug_log("Reader empty; entering card selection with %d cards" % held_cards.size())
	_enter_card_selection_mode(reader, held_cards)


func _get_held_cards() -> Array:
	var cards: Array = []
	for held_item in _held_interactables:
		if held_item.is_card():
			cards.append(held_item)
	return cards


func _enter_card_selection_mode(reader: CardReaderScript, held_cards: Array) -> void:
	_cancel_card_selection_mode()
	_pending_card_reader = reader
	_awaiting_card_selection = true
	_eligible_held_cards = held_cards.duplicate()

	_debug_log("Card selection started: %d eligible cards" % _eligible_held_cards.size())
	_update_hint_text()


func _cancel_card_selection_mode() -> void:
	if _awaiting_card_selection:
		_debug_log("Card selection cancelled")
	_awaiting_card_selection = false
	_pending_card_reader = null
	for card in _eligible_held_cards:
		if card != null and is_instance_valid(card):
			card.set_visual_state(InteractableScript.VisualState.HELD)
	_eligible_held_cards.clear()
	_update_hint_text()


func _apply_card_to_pending_reader(card) -> void:
	if _pending_card_reader == null or card == null:
		_debug_log("Card apply failed: pending reader or card missing")
		_cancel_card_selection_mode()
		return
	if not _is_item_currently_held(card):
		_debug_log("Card apply failed: card not held %s" % _describe_interactable(card))
		_cancel_card_selection_mode()
		return
	if not _pending_card_reader.can_accept_card(card):
		_debug_log("Card apply rejected by reader for %s" % _describe_interactable(card))
		_update_hint_text()
		return

	var removed_card = _remove_held_item(card)
	if removed_card == null:
		_debug_log("Card apply failed: could not remove held card")
		_cancel_card_selection_mode()
		return

	removed_card.set_held(true)
	if not _pending_card_reader.insert_card(removed_card):
		_debug_log("Card apply failed: reader insert returned false; reattaching")
		_attach_item_to_hands(removed_card, false)
	else:
		_debug_log("Card inserted successfully: %s" % _describe_interactable(removed_card))

	_cancel_card_selection_mode()
	_update_hint_text()


func _debug_log(message: String) -> void:
	if not debug_interaction_logs:
		return
	print("[InteractionController] %s" % message)


func _describe_interactable(item) -> String:
	if item == null:
		return "null"
	return "%s(id=%s)" % [item.display_name, item.item_id]


func _set_hovered_interactable(target, in_range: bool, blocked: bool) -> void:
	if _hovered_interactable != null and _hovered_interactable != target:
		if _is_item_currently_held(_hovered_interactable):
			_hovered_interactable.set_visual_state(InteractableScript.VisualState.HELD)
		else:
			_hovered_interactable.set_visual_state(InteractableScript.VisualState.IDLE)

	_hovered_interactable = target
	_hovered_in_range = in_range and not blocked
	_hovered_blocked = blocked

	if _hovered_interactable != null:
		if _is_item_currently_held(_hovered_interactable):
			_hovered_interactable.set_visual_state(InteractableScript.VisualState.HOVERED)
		elif _hovered_blocked:
			_hovered_interactable.set_visual_state(InteractableScript.VisualState.BLOCKED)
		elif _hovered_in_range:
			_hovered_interactable.set_visual_state(InteractableScript.VisualState.IN_RANGE)
		else:
			_hovered_interactable.set_visual_state(InteractableScript.VisualState.HOVERED)

	_update_hint_text()


func _is_interactable_in_range(target) -> bool:
	return target.can_interact_from(_player.global_position)


func _has_line_of_sight(target) -> bool:
	var from: Vector3 = _player.global_position + Vector3(0.0, 0.9, 0.0)
	var to: Vector3 = target.get_focus_position()
	var target_root = target.get_pickup_root()
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# LOS should be blocked by level/world geometry, not by unrelated interactable areas.
	query.collision_mask = WALL_COLLISION_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_player, target, target_root]

	var result = _world_root.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Variant = result.collider
	if _collider_belongs_to_target(target, target_root, collider):
		return true
	return false


func _collider_belongs_to_target(target, target_root, collider: Variant) -> bool:
	if collider == null:
		return false
	if collider == target or collider == target_root:
		return true
	if not (collider is Node):
		return false
	var collider_node := collider as Node
	if target is Node:
		var target_node := target as Node
		if target_node.is_ancestor_of(collider_node) or collider_node.is_ancestor_of(target_node):
			return true
		var target_host := target_node.get_parent()
		if target_host != null and (target_host.is_ancestor_of(collider_node) or collider_node.is_ancestor_of(target_host)):
			return true
	if target_root is Node:
		var root_node := target_root as Node
		if root_node.is_ancestor_of(collider_node) or collider_node.is_ancestor_of(root_node):
			return true
	return false


func _get_code_panel_for_interactable(target) -> CodePanelScript:
	if target == null:
		return null
	var node = target.get_parent()
	while node != null:
		if node is CodePanelScript:
			return node as CodePanelScript
		node = node.get_parent()
	return null


func _move_toward_interactable(target) -> void:
	var player_pos: Vector3 = _player.global_position
	var target_pos: Vector3 = target.get_focus_position()
	var away: Vector3 = player_pos - target_pos
	away.y = 0.0

	if away.length() <= 0.01:
		away = Vector3.BACK
	else:
		away = away.normalized()

	var standoff = interact_move_standoff
	if _get_card_reader_for_interactable(target) != null:
		standoff = maxf(standoff, 2.6)

	var move_position: Vector3 = target_pos + away * standoff
	move_position.y = player_pos.y
	_player.set_move_target(move_position)


func _pick_up_interactable(target) -> void:
	if _held_interactables.size() >= max_held_items or _is_item_currently_held(target):
		return

	if not _attach_item_to_hands(target, true):
		return

	target.interact(_player)
	_player.clear_move_target()
	_cancel_card_selection_mode()


func _drop_last_held_item() -> void:
	if _held_interactables.is_empty():
		return
	_drop_held_item_by_index(_held_interactables.size() - 1)


func _drop_specific_held_item(item) -> void:
	var index = _held_interactables.find(item)
	if index == -1:
		return
	_drop_held_item_by_index(index)


func _drop_all_held_items() -> void:
	while not _held_interactables.is_empty():
		_drop_held_item_by_index(_held_interactables.size() - 1)


func _drop_held_item_by_index(index: int) -> void:
	if index < 0 or index >= _held_interactables.size():
		return

	var item = _held_interactables[index]
	item = _remove_held_item(item)
	if item == null:
		return

	var pickup_root = item.get_pickup_root()
	pickup_root.reparent(_world_root, true)
	item.set_held(false)
	item.drop(_player)

	var lateral_offset = _player.global_basis.x * (0.2 * float(index % 3 - 1))
	var drop_position: Vector3 = _player.global_position + _player.global_basis.z * 1.25 + Vector3(0.0, 0.6, 0.0) + lateral_offset
	drop_position.x = clampf(drop_position.x, -drop_clamp_extent, drop_clamp_extent)
	drop_position.z = clampf(drop_position.z, -drop_clamp_extent, drop_clamp_extent)
	pickup_root.global_position = drop_position
	if pickup_root is RigidBody3D:
		var body = pickup_root as RigidBody3D
		body.linear_velocity = _player.velocity * 0.35 + Vector3(0.0, 0.5, 0.0)

	if _hovered_interactable == item:
		_set_hovered_interactable(null, false, false)

	_cancel_card_selection_mode()
	_update_hint_text()


func _update_held_item_transform(delta: float) -> void:
	if _held_interactables.is_empty():
		return
	_focus_reject_feedback.tick(delta)
	_update_hand_sockets_from_rig()

	if _focus_display_enabled and _focus_display_camera != null:
		_update_focus_display_transforms(delta)
		return

	var alpha = minf(1.0, held_item_follow_speed * delta)
	for held_item in _held_interactables:
		var item_id = held_item.get_instance_id()
		var socket_index = int(_held_socket_by_item_id.get(item_id, -1))
		if socket_index < 0 or socket_index >= _hand_sockets.size():
			continue
		var pickup_root = held_item.get_pickup_root()
		var socket = _hand_sockets[socket_index]
		var target_transform = socket.global_transform * held_item.get_hold_transform()
		pickup_root.global_transform = pickup_root.global_transform.interpolate_with(target_transform, alpha)
		_reapply_held_global_scale(item_id, pickup_root)


func _update_focus_display_transforms(delta: float) -> void:
	var count = _held_interactables.size()
	var columns = mini(count, 4)
	var alpha = minf(1.0, held_item_follow_speed * delta)
	var bottom_anchor = -1.34
	var row_spacing = 0.58

	for i in range(count):
		var held_item = _held_interactables[i]
		var item_id = held_item.get_instance_id()
		var pickup_root = held_item.get_pickup_root()
		var col = i % columns
		var row = i / columns
		var offset_x = (float(col) - float(columns - 1) * 0.5) * 0.82
		var offset_y = bottom_anchor + float(row) * row_spacing

		var camera_forward = -_focus_display_camera.global_basis.z
		var camera_right = _focus_display_camera.global_basis.x
		var camera_up = _focus_display_camera.global_basis.y

		var target_pos = _focus_display_camera.global_position
		target_pos += camera_forward * 2.2
		target_pos += camera_right * offset_x
		target_pos += camera_up * offset_y
		target_pos += _focus_reject_feedback.get_offset(
			held_item,
			target_pos,
			_get_focus_reject_target_position(target_pos)
		)

		var target_basis = Basis.looking_at(-camera_forward, Vector3.UP)
		var target_transform = Transform3D(target_basis, target_pos)
		pickup_root.global_transform = pickup_root.global_transform.interpolate_with(target_transform, alpha)
		_reapply_held_global_scale(item_id, pickup_root)


func _trigger_focus_reject_feedback(item) -> void:
	if item == null or not _focus_locked:
		return
	_focus_reject_feedback.trigger(item)


func _try_apply_focus_held_item(item) -> void:
	if item == null:
		return
	if _can_focus_target_accept_held_item(item):
		_apply_held_item_to_focus_target(item)
		return
	_debug_log("Focus-held click rejected for %s" % _describe_interactable(item))
	_trigger_focus_reject_feedback(item)


func _get_focus_reject_target_position(fallback_position: Vector3) -> Vector3:
	return _get_focus_item_target_position(fallback_position)


func _can_focus_target_accept_held_item(item) -> bool:
	if item == null:
		return false

	# Extension point: add additional focus-target handlers here as new
	# interactable types gain held-item application behavior.
	if _focus_card_reader != null:
		return item.is_card() and _focus_card_reader.can_accept_card(item)

	return false


func _apply_held_item_to_focus_target(item) -> void:
	if item == null:
		return

	# Extension point: mirror branching in _can_focus_target_accept_held_item.
	if _focus_card_reader != null:
		_debug_log("Focus-held click applies card %s" % _describe_interactable(item))
		_pending_card_reader = _focus_card_reader
		_apply_card_to_pending_reader(item)


func _get_focus_item_target_position(fallback_position: Vector3) -> Vector3:
	# Extension point: return a destination position per focus-target type.
	if _focus_card_reader != null:
		return _focus_card_reader.get_slot_position()
	if _focus_target != null:
		return _focus_target.get_focus_position()
	return fallback_position


func _ensure_hand_sockets() -> void:
	var sockets_root: Node3D = _player.get_node_or_null("HandSockets") as Node3D
	if sockets_root == null:
		sockets_root = Node3D.new()
		sockets_root.name = "HandSockets"
		_player.add_child(sockets_root)

	var existing_count = sockets_root.get_child_count()
	for i in range(existing_count, max_held_items):
		var socket = Node3D.new()
		socket.name = "HandSocket%d" % i
		sockets_root.add_child(socket)

	_hand_sockets.clear()
	var child_index = 0
	for child in sockets_root.get_children():
		if child_index >= max_held_items:
			break
		if child is Node3D:
			_hand_sockets.append(child as Node3D)
			child_index += 1

	_refresh_hand_socket_layout()


func _refresh_hand_socket_layout() -> void:
	var radius = lerpf(hand_socket_inner_radius, hand_socket_outer_radius, 1.0)
	var angle_offset = PI * 0.5
	for i in range(_hand_sockets.size()):
		var socket = _hand_sockets[i]
		var angle = TAU * float(i) / float(maxi(_hand_sockets.size(), 1)) + angle_offset
		if _arm_name_by_socket_index.has(i):
			var arm_name = str(_arm_name_by_socket_index[i])
			if ARM_SOCKET_ANGLE_BY_NAME.has(arm_name):
				angle = float(ARM_SOCKET_ANGLE_BY_NAME[arm_name])
		var local_pos = Vector3(cos(angle) * radius, hand_socket_height, sin(angle) * radius)
		socket.position = local_pos

		var outward = Vector3(local_pos.x, 0.0, local_pos.z).normalized()
		if outward.length() > 0.001:
			socket.rotation.y = atan2(outward.x, outward.z)


func _is_item_currently_held(item) -> bool:
	if item == null:
		return false
	return _held_socket_by_item_id.has(item.get_instance_id())


func _remove_held_item(item) :
	if item == null:
		return null
	var index = _held_interactables.find(item)
	if index == -1:
		return null
	var item_id = item.get_instance_id()
	var socket_index = int(_held_socket_by_item_id.get(item_id, -1))
	_held_socket_by_item_id.erase(item_id)
	if socket_index >= 0:
		_set_hold_state_for_socket(socket_index, false)
	_held_interactables.remove_at(index)
	_held_global_scale_by_item_id.erase(item_id)
	_held_clearance_by_item_id.erase(item_id)
	_update_carry_mobility()
	return item


func _attach_item_to_hands(item, clear_motion_target: bool) -> bool:
	if item == null:
		return false
	if _held_interactables.size() >= max_held_items:
		return false
	if _is_item_currently_held(item):
		return true

	var socket_index = _find_free_socket_index()
	if socket_index < 0 or socket_index >= _hand_sockets.size():
		return false

	_held_interactables.append(item)
	var item_id = item.get_instance_id()
	_held_socket_by_item_id[item_id] = socket_index
	_set_hold_state_for_socket(socket_index, true)

	var pickup_root = item.get_pickup_root()
	var socket = _hand_sockets[socket_index]
	_held_global_scale_by_item_id[item_id] = pickup_root.global_basis.get_scale().abs()
	_held_clearance_by_item_id[item_id] = _estimate_item_clearance(item, pickup_root)
	pickup_root.reparent(socket, true)
	item.set_interaction_enabled(true)
	item.set_held(true)
	pickup_root.transform = item.get_hold_transform()
	_reapply_held_global_scale(item_id, pickup_root)

	if clear_motion_target:
		_player.clear_move_target()

	_update_carry_mobility()
	return true


func _resolve_octo_rig() -> void:
	_octo_rig = null
	if _player == null:
		return
	var visual = _player.get_node_or_null("PlayerVisual")
	if visual is OctoRigScript:
		_octo_rig = visual as OctoRigScript


func _configure_hold_arm_slot_mapping() -> void:
	_socket_index_by_arm_name.clear()
	_arm_name_by_socket_index.clear()
	var arm_priority = _resolve_hold_arm_priority()
	var count = mini(_hand_sockets.size(), arm_priority.size())
	for i in range(count):
		var arm_name = str(arm_priority[i])
		_socket_index_by_arm_name[arm_name] = i
		_arm_name_by_socket_index[i] = arm_name


func _resolve_hold_arm_priority() -> PackedStringArray:
	if _octo_rig != null and _octo_rig.has_method("get_hold_arm_priority"):
		var value: Variant = _octo_rig.call("get_hold_arm_priority")
		if value is PackedStringArray:
			return value
		if value is Array:
			var result := PackedStringArray()
			for arm_name in value:
				result.append(str(arm_name))
			return result
	return FALLBACK_HOLD_ARM_PRIORITY


func _find_free_socket_index() -> int:
	for i in range(_hand_sockets.size()):
		if _arm_name_by_socket_index.has(i) and not _is_socket_occupied(i):
			return i
	for i in range(_hand_sockets.size()):
		if not _arm_name_by_socket_index.has(i):
			if not _is_socket_occupied(i):
				return i
	return -1


func _is_socket_occupied(socket_index: int) -> bool:
	for value in _held_socket_by_item_id.values():
		if int(value) == socket_index:
			return true
	return false


func _set_hold_state_for_socket(socket_index: int, holding: bool) -> void:
	if _octo_rig == null:
		return
	if not _arm_name_by_socket_index.has(socket_index):
		return
	var arm_name = str(_arm_name_by_socket_index[socket_index])
	if arm_name.is_empty():
		return
	_octo_rig.set_arm_hold_enabled(arm_name, holding)


func _update_hand_sockets_from_rig() -> void:
	if _octo_rig == null or _player == null:
		return
	var lift_offset = Vector3(0.0, 0.06, 0.0)
	for socket_index_variant in _arm_name_by_socket_index.keys():
		var socket_index = int(socket_index_variant)
		if socket_index < 0 or socket_index >= _hand_sockets.size():
			continue
		if not _is_socket_occupied(socket_index):
			continue
		var arm_name = str(_arm_name_by_socket_index[socket_index])
		var world_anchor: Vector3 = _octo_rig.get_arm_world_anchor(arm_name, "tip")
		var item_id = _get_item_id_for_socket(socket_index)
		var clearance = float(_held_clearance_by_item_id.get(item_id, 0.0)) if item_id >= 0 else 0.0
		var radial = world_anchor - _player.global_position
		radial.y = 0.0
		if radial.length_squared() <= 0.0001:
			radial = _player.global_basis.z
			radial.y = 0.0
		radial = radial.normalized()
		var world_pos = world_anchor + lift_offset + radial * clearance + Vector3(0.0, clearance * 0.2, 0.0)
		world_pos.y = maxf(world_pos.y, _player.global_position.y + held_item_min_world_height)
		var local_anchor = _player.to_local(world_pos)
		_hand_sockets[socket_index].position = local_anchor


func _get_item_id_for_socket(socket_index: int) -> int:
	for item_id_variant in _held_socket_by_item_id.keys():
		if int(_held_socket_by_item_id[item_id_variant]) == socket_index:
			return int(item_id_variant)
	return -1


func _reapply_held_global_scale(item_id: int, pickup_root: Node3D) -> void:
	if pickup_root == null:
		return
	var held_scale_variant: Variant = _held_global_scale_by_item_id.get(item_id, null)
	if held_scale_variant == null:
		return
	var held_global_scale = held_scale_variant as Vector3
	var current_global = pickup_root.global_transform
	var rotation_basis = current_global.basis.orthonormalized()
	current_global.basis = rotation_basis.scaled(held_global_scale)
	pickup_root.global_transform = current_global


func _estimate_item_clearance(item, root: Node3D) -> float:
	if root == null:
		return 0.0
	if item != null and item.has_method("is_card") and bool(item.is_card()):
		return 0.0
	var max_extent = _estimate_mesh_max_extent(root)
	# Keep small props close; push larger objects outward enough to avoid body clipping.
	return clampf((max_extent - 0.2) * 0.7, 0.0, held_item_clearance_max)


func _estimate_mesh_max_extent(root: Node3D) -> float:
	var max_extent = 0.0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance = node as MeshInstance3D
			if mesh_instance.mesh != null:
				var aabb = mesh_instance.mesh.get_aabb()
				var local_size = aabb.size.abs()
				var world_scale = mesh_instance.global_basis.get_scale().abs()
				var scaled_size = Vector3(
					local_size.x * world_scale.x,
					local_size.y * world_scale.y,
					local_size.z * world_scale.z
				)
				max_extent = maxf(max_extent, maxf(scaled_size.x, maxf(scaled_size.y, scaled_size.z)))
		for child in node.get_children():
			stack.append(child)
	return max_extent


func _update_carry_mobility() -> void:
	var held_count = _held_interactables.size()
	if _focus_locked:
		_player.move_speed = 0.0
		_player.clear_move_target()
	elif held_count >= immobilized_at_item_count:
		_player.move_speed = 0.0
		_player.clear_move_target()
	elif held_count >= slow_at_item_count:
		_player.move_speed = _base_move_speed * heavy_carry_speed_multiplier
	else:
		_player.move_speed = _base_move_speed


func _is_movement_blocked_by_full_load() -> bool:
	return _held_interactables.size() >= immobilized_at_item_count


func _trigger_blocked_move_feedback() -> void:
	_queued_interaction_target = null
	_player.clear_move_target()
	if _player != null and _player.has_method("trigger_blocked_move_feedback"):
		_player.call("trigger_blocked_move_feedback")


func _setup_scene_interactables() -> void:
	var button = _world_root.get_node_or_null("Interactables/LightButton/Interactable")
	if button == null:
		return

	var handler = _on_button_clicked.bind(button.get_parent() as StaticBody3D)
	if not button.clicked.is_connected(handler):
		button.clicked.connect(handler)


func _update_hint_text() -> void:
	if _hint_label == null:
		return

	var context = {
		"focus_locked": _focus_locked,
		"hovered_name": _hovered_interactable.display_name if _hovered_interactable != null else "",
		"hovered_is_held": _is_item_currently_held(_hovered_interactable) if _hovered_interactable != null else false,
		"hovered_blocked": _hovered_blocked,
		"hovered_in_range": _hovered_in_range,
		"hovered_prompt": _hovered_interactable.prompt_action if _hovered_interactable != null else "Interact",
		"held_count": _held_interactables.size(),
		"max_held": max_held_items,
		"immobilized_at": immobilized_at_item_count,
		"slow_at": slow_at_item_count,
		"queued_target_name": _queued_interaction_target.display_name if _queued_interaction_target != null and is_instance_valid(_queued_interaction_target) else "",
		"awaiting_card_selection": _awaiting_card_selection and _pending_card_reader != null,
	}
	var lines = _hint_builder.build_lines(context)
	_hint_label.text = "\n".join(lines)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _on_button_clicked(_interactable, _actor: Node, button_body: StaticBody3D) -> void:
	_light_toggle_on = not _light_toggle_on
	_room_light.light_energy = _default_light_energy if _light_toggle_on else 0.35

	if button_body.has_node("MeshInstance3D"):
		var mesh = button_body.get_node("MeshInstance3D") as MeshInstance3D
		mesh.material_override = _make_material(
			Color(0.84, 0.24, 0.2, 1.0) if _light_toggle_on else Color(0.36, 0.36, 0.38, 1.0),
			0.5
		)
