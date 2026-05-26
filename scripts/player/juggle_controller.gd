extends Node
class_name JuggleController

## Drives juggling for all ball-type held items.
##
## Anchor: live socket + interactable hold transform each frame (when socket
## exists), so arc bottom tracks actual held position including hold offsets.
## Falls back to snapshotted player-local anchor if socket is unavailable.
##
## Tip gesture: a smooth sin pulse on OctoRig._juggle_tip_bend_additive,
## only the arm tip bends — no whole-arm gesture animation.
##
## Called manually from InteractionController.process_interactions — no _process.

const TheBallScript = preload("res://scripts/station/items/the_ball.gd")

@export var beat_count: int = 8
@export var beat_duration: float = 0.72   # seconds per beat
@export var pre_toss_delay: float = 0.18  # seconds ball sits at rest before first toss
@export var arc_height: float = 0.46      # self-toss arc height (m)
@export var forward_offset: float = 0.04  # self-toss forward sway (m)
@export var lane_arc_height: float = 0.55
@export var lane_forward_offset: float = 0.03

## Tip-bend gesture at toss/catch.  Applied additively on top of hold_tip_bend.
@export var juggle_tip_bend_amount: float = 0.45   # peak additive tip bend
@export var juggle_tip_hold_time:   float = 0.06   # seconds the tip holds at peak
@export var juggle_tip_rise_speed:  float = 30.0   # lerp speed (1/s) rising to peak
@export var juggle_tip_fall_speed:  float = 7.0    # lerp speed (1/s) falling to rest
@export var debug_ball_arm_mapping: bool = false

var active: bool = false
var total_time: float = 0.0
var _stop_requested: bool = false
var _hold_mode: bool = false
var _juggled_ball_ids: Dictionary = {}
var _ball_arm_assignment: Dictionary = {}
var _blocked_arms: Dictionary = {}  # arm_name -> true (occupied by non-ball held items)

var _player: CharacterBody3D
var _octo_rig: Node

## Per-arm tip-bend spring state.
## arm_name → { value: float, target: float, hold: float }
##   value  – current additive bend sent to OctoRig each frame
##   target – value is lerped toward this (amount when triggered, 0 when falling)
##   hold   – seconds remaining at peak before target resets to 0
var _tip_state: Dictionary = {}

## Lane dict keys:
##   arm_a / arm_b       String  – arm names (equal for self-toss)
##   rest_local_a / _b   Vector3 – frozen anchor in player-local space
##   balls               Array   – BallState dicts
var _lanes: Array = []


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

func initialize(player: CharacterBody3D, octo_rig: Node) -> void:
	_player = player
	_octo_rig = octo_rig


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func on_ball_picked_up(item: Node, arm_name: String, socket: Node3D = null) -> void:
	if not _is_ball(item):
		return
	var had_existing_balls := _count_balls() > 0
	if not active:
		_start()

	# Snapshot from the ACTUAL held item position.
	# This guarantees juggle starts from the same point as visual hold, including
	# Interactable hold_offset/hold_rotation adjustments already applied on attach.
	var rest_local := Vector3.ZERO
	if _player != null and item.has_method("get_pickup_root"):
		var pickup_root: Node3D = item.get_pickup_root()
		if pickup_root != null:
			rest_local = _player.to_local(pickup_root.global_position)
		elif socket != null:
			# Fallback only if pickup_root is missing.
			rest_local = _player.to_local(socket.global_position)

	_add_ball(item, arm_name, rest_local, socket)
	if had_existing_balls:
		_restart_pattern_from_start()

	# Snap ball to arc start immediately — prevents one-frame position jump.
	var pickup_root: Node3D = item.get_pickup_root()
	if pickup_root != null and _player != null and rest_local != Vector3.ZERO:
		pickup_root.global_position = _player.to_global(rest_local)


func rebuild_from_held_items(
	held_items: Array,
	held_socket_by_item_id: Dictionary,
	hand_sockets: Array,
	arm_name_by_socket_index: Dictionary
) -> void:
	var was_motion_active := active and not _hold_mode
	var raw_ball_entries: Array = []
	var new_ball_ids: Dictionary = {}
	_blocked_arms = _collect_blocked_arms_from_held_items(held_items, held_socket_by_item_id, arm_name_by_socket_index)
	for held_item in held_items:
		if not _is_ball(held_item):
			continue
		if not held_item.has_method("get_pickup_root"):
			continue
		var pickup_root: Node3D = held_item.get_pickup_root()
		if pickup_root == null:
			continue
		var item_id: int = held_item.get_instance_id()
		new_ball_ids[item_id] = true
		var rest_local := _player.to_local(pickup_root.global_position) if _player != null else Vector3.ZERO
		raw_ball_entries.append({
			"item": held_item,
			"item_id": item_id,
			"world_pos": pickup_root.global_position,
			"rest_local": rest_local,
		})

	var ball_entries := _assign_sockets_to_ball_entries(
		raw_ball_entries,
		hand_sockets,
		arm_name_by_socket_index,
		held_socket_by_item_id,
		not _hold_mode
	)

	if ball_entries.is_empty():
		_end()
		_juggled_ball_ids.clear()
		return

	var previous_count := _juggled_ball_ids.size()
	var new_count := new_ball_ids.size()
	var ids_unchanged := _ball_id_sets_equal(_juggled_ball_ids, new_ball_ids)
	var balls_added := new_count > previous_count

	if ids_unchanged:
		return

	if not active or _hold_mode:
		_start()
	_juggled_ball_ids = new_ball_ids.duplicate()
	if ball_entries.size() >= 3:
		_build_cycle_lane_from_ball_entries(ball_entries)
	else:
		_build_lanes_from_ball_entries(ball_entries)
	if balls_added and not was_motion_active:
		_tip_state.clear()
		_restart_pattern_from_start()
	_prune_ball_arm_assignments(new_ball_ids)
	_debug_log_mapping("rebuild")


func on_ball_dropped(item: Node) -> void:
	if not active:
		return
	if not _is_ball(item):
		return
	if item != null and is_instance_valid(item):
		_juggled_ball_ids.erase(item.get_instance_id())
		_ball_arm_assignment.erase(item.get_instance_id())
	_remove_ball(item)
	if _count_balls() == 0:
		_end()


func is_juggling_ball(item: Node) -> bool:
	if not active:
		return false
	for lane in _lanes:
		for ball_state in lane["balls"]:
			if ball_state["item"] == item:
				return true
	return false


func is_ball_item(item: Node) -> bool:
	return _is_ball(item)


func is_in_hold_mode() -> bool:
	return active and _hold_mode


func get_ball_assigned_arm(item: Node) -> String:
	if item == null or not is_instance_valid(item):
		return ""
	for lane in _lanes:
		for ball_state in lane["balls"]:
			if ball_state.get("item", null) != item:
				continue
			if bool(ball_state.get("retired", false)):
				return str(ball_state.get("retired_arm", ""))
			return str(ball_state.get("arm_name", ""))
	return ""


func process_juggle(delta: float) -> void:
	if not active:
		return
	if _hold_mode:
		for lane in _lanes:
			for ball_state in lane["balls"]:
				_update_ball_position(ball_state, lane)
		_update_tip_pulses(delta)
		return
	total_time += delta
	if not _stop_requested and total_time >= float(beat_count) * beat_duration:
		_stop_requested = true
		_request_all_balls_retire_on_catch()
	if total_time < 0.0:
		_refresh_lane_rest_anchors_from_held_items()
	_update_tip_pulses(delta)
	for lane in _lanes:
		for ball_state in lane["balls"]:
			_update_ball_position(ball_state, lane)
			_check_gestures(ball_state, lane)
	if _stop_requested and _all_balls_retired():
		_stop_requested = false
		_hold_mode = true
		_tip_state.clear()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _start() -> void:
	active = true
	total_time = -pre_toss_delay  # negative → ball stays at rest until t reaches 0
	_stop_requested = false
	_hold_mode = false
	_lanes.clear()
	_tip_state.clear()


func _end() -> void:
	active = false
	_lanes.clear()
	_tip_state.clear()
	_hold_mode = false
	_juggled_ball_ids.clear()
	_ball_arm_assignment.clear()
	_blocked_arms.clear()
	if _octo_rig != null and _octo_rig.has_method("clear_all_juggle_tip_bends"):
		_octo_rig.clear_all_juggle_tip_bends()


func _restart_pattern_from_start() -> void:
	total_time = -pre_toss_delay
	_stop_requested = false
	_hold_mode = false
	_tip_state.clear()
	for lane in _lanes:
		for ball_state in lane["balls"]:
			ball_state["toss_fired"] = false
			ball_state["catch_fired"] = false
			ball_state["last_beat"] = -1
			ball_state["retire_on_catch"] = false
			ball_state["retired"] = false
			ball_state["retired_arm"] = ""
			ball_state["retire_seen_beat"] = -1


# ---------------------------------------------------------------------------
# Lane management
# ---------------------------------------------------------------------------

func _add_ball(item: Node, arm_name: String, rest_local: Vector3, socket: Node3D = null) -> void:
	# If we already have a single-ball self lane on another arm, promote it to
	# a 2-ball cross lane so balls can switch hands.
	for lane in _lanes:
		var lane_arm_a := str(lane["arm_a"])
		var lane_arm_b := str(lane["arm_b"])
		var balls: Array = lane["balls"]
		if balls.size() == 1 and lane_arm_a == lane_arm_b and lane_arm_a != arm_name:
			lane["arm_b"] = arm_name
			lane["rest_local_b"] = rest_local
			lane["socket_b"] = socket
			balls.append(_make_ball_state(item, arm_name, socket, rest_local))
			_configure_lane_ball_timing(lane)
			return

	_lanes.append({
		"arm_a": arm_name,
		"arm_b": arm_name,
		"rest_local_a": rest_local,
		"rest_local_b": rest_local,
		"socket_a": socket,
		"socket_b": socket,
		"balls": [_make_ball_state(item, arm_name, socket, rest_local)],
	})
	_configure_lane_ball_timing(_lanes[_lanes.size() - 1])


func _remove_ball(item: Node) -> void:
	for lane_idx in _lanes.size():
		var lane: Dictionary = _lanes[lane_idx]
		var balls: Array = lane["balls"]
		for ball_idx in balls.size():
			if balls[ball_idx]["item"] == item:
				balls.remove_at(ball_idx)
				if balls.is_empty():
					_lanes.remove_at(lane_idx)
				else:
					_configure_lane_ball_timing(lane)
				return


func _count_balls() -> int:
	var total := 0
	for lane in _lanes:
		total += lane["balls"].size()
	return total


func _ball_id_sets_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for id_key in a.keys():
		if not b.has(id_key):
			return false
	return true


func _prune_ball_arm_assignments(valid_ids: Dictionary) -> void:
	var to_erase: Array = []
	for id_key in _ball_arm_assignment.keys():
		if not valid_ids.has(id_key):
			to_erase.append(id_key)
	for id_key in to_erase:
		_ball_arm_assignment.erase(id_key)


func _record_ball_arm_assignment(item: Node, arm_name: String) -> void:
	if item == null or not is_instance_valid(item):
		return
	if arm_name.is_empty():
		return
	_ball_arm_assignment[item.get_instance_id()] = arm_name


func _assign_sockets_to_ball_entries(
	raw_entries: Array,
	hand_sockets: Array,
	arm_name_by_socket_index: Dictionary,
	held_socket_by_item_id: Dictionary,
	use_cached_assignment: bool
) -> Array:
	var result: Array = []
	if raw_entries.is_empty():
		return result

	var socket_index_by_arm_name: Dictionary = {}
	for socket_index_variant in arm_name_by_socket_index.keys():
		var socket_index := int(socket_index_variant)
		var mapped_arm_name := str(arm_name_by_socket_index[socket_index_variant])
		if not mapped_arm_name.is_empty():
			if _blocked_arms.has(mapped_arm_name):
				continue
			socket_index_by_arm_name[mapped_arm_name] = socket_index

	var pairs: Array = []
	for e_idx in range(raw_entries.size()):
		var item_id := int(raw_entries[e_idx]["item_id"])
		if use_cached_assignment and _ball_arm_assignment.has(item_id):
			var preferred_arm := str(_ball_arm_assignment[item_id])
			if socket_index_by_arm_name.has(preferred_arm):
				var preferred_socket_idx := int(socket_index_by_arm_name[preferred_arm])
				var preferred_socket := hand_sockets[preferred_socket_idx] as Node3D
				if preferred_socket != null and is_instance_valid(preferred_socket):
					# Negative weight guarantees persistent visual assignment wins.
					pairs.append({"e": e_idx, "s": preferred_socket_idx, "d2": -1.0})
		var world_pos: Vector3 = raw_entries[e_idx]["world_pos"]
		for s_idx in range(hand_sockets.size()):
			var socket := hand_sockets[s_idx] as Node3D
			if socket == null or not is_instance_valid(socket):
				continue
			var d2 := socket.global_position.distance_squared_to(world_pos)
			pairs.append({"e": e_idx, "s": s_idx, "d2": d2})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d2"]) < float(b["d2"])
	)

	var entry_to_socket: Dictionary = {}
	var used_sockets: Dictionary = {}
	for p in pairs:
		var e_idx := int(p["e"])
		var s_idx := int(p["s"])
		if entry_to_socket.has(e_idx):
			continue
		if used_sockets.has(s_idx):
			continue
		entry_to_socket[e_idx] = s_idx
		used_sockets[s_idx] = true

	# Fill any unmatched entries from previous held mapping.
		for fallback_entry_idx in range(raw_entries.size()):
			if entry_to_socket.has(fallback_entry_idx):
				continue
			var item_id := int(raw_entries[fallback_entry_idx]["item_id"])
			var fallback_idx := int(held_socket_by_item_id.get(item_id, -1))
			if fallback_idx >= 0 and fallback_idx < hand_sockets.size() and not used_sockets.has(fallback_idx):
				var fallback_arm := str(arm_name_by_socket_index.get(fallback_idx, ""))
				if fallback_arm.is_empty() or _blocked_arms.has(fallback_arm):
					continue
				entry_to_socket[fallback_entry_idx] = fallback_idx
				used_sockets[fallback_idx] = true

	for e_idx in range(raw_entries.size()):
		var raw: Dictionary = raw_entries[e_idx]
		var socket_idx := int(entry_to_socket.get(e_idx, -1))
		var socket: Node3D = null
		if socket_idx >= 0 and socket_idx < hand_sockets.size():
			socket = hand_sockets[socket_idx]
		var arm_name := str(arm_name_by_socket_index.get(socket_idx, ""))
		var item_id := int(raw["item_id"])
		if not arm_name.is_empty():
			_ball_arm_assignment[item_id] = arm_name
		result.append({
			"item": raw["item"],
			"item_id": item_id,
			"arm_name": arm_name,
			"socket": socket,
			"rest_local": raw["rest_local"],
		})
	return result


func _debug_log_mapping(reason: String) -> void:
	if not debug_ball_arm_mapping:
		return
	var parts: Array[String] = []
	for lane in _lanes:
		for ball_state in lane["balls"]:
			var item: Node = ball_state.get("item", null)
			if item == null or not is_instance_valid(item):
				continue
			var item_id: int = item.get_instance_id()
			var arm_name := str(ball_state.get("retired_arm", "")) if bool(ball_state.get("retired", false)) else str(ball_state.get("arm_name", ""))
			parts.append("%s->%s" % [str(item_id), arm_name])
	print("[JuggleController] %s %s" % [reason, ", ".join(parts)])


# ---------------------------------------------------------------------------
# Ball state
# ---------------------------------------------------------------------------

func _make_ball_state(item: Node, arm_name: String = "", socket: Node3D = null, rest_local: Vector3 = Vector3.ZERO) -> Dictionary:
	return {
		"item": item,
		"arm_name": arm_name,
		"socket": socket,
		"rest_local": rest_local,
		"start_delay": 0.0,  # seconds before first toss
		"start_from_a": true,
		"toss_fired": false,
		"catch_fired": false,
		"last_beat": -1,
		"retire_on_catch": false,
		"retired": false,
		"retired_arm": "",
		"retire_seen_beat": -1,
	}


func _build_lanes_from_ball_entries(ball_entries: Array) -> void:
	_lanes.clear()
	var remaining: Array = ball_entries.duplicate()
	while true:
		var first_idx := -1
		var second_idx := -1
		for i in range(remaining.size()):
			for j in range(i + 1, remaining.size()):
				var arm_i := str(remaining[i]["arm_name"])
				var arm_j := str(remaining[j]["arm_name"])
				if not arm_i.is_empty() and not arm_j.is_empty() and arm_i != arm_j:
					first_idx = i
					second_idx = j
					break
			if first_idx >= 0:
				break
		if first_idx < 0 or second_idx < 0:
			break
		var a: Dictionary = remaining[first_idx]
		var b: Dictionary = remaining[second_idx]
		var cross_lane := {
			"arm_a": str(a["arm_name"]),
			"arm_b": str(b["arm_name"]),
			"rest_local_a": a["rest_local"],
			"rest_local_b": b["rest_local"],
			"socket_a": a["socket"],
			"socket_b": b["socket"],
			"balls": [
				_make_ball_state(a["item"], str(a["arm_name"]), a["socket"], a["rest_local"]),
				_make_ball_state(b["item"], str(b["arm_name"]), b["socket"], b["rest_local"])
			],
		}
		_lanes.append(cross_lane)
		_configure_lane_ball_timing(cross_lane)
		if second_idx > first_idx:
			remaining.remove_at(second_idx)
			remaining.remove_at(first_idx)
		else:
			remaining.remove_at(first_idx)
			remaining.remove_at(second_idx)
	for e in remaining:
		var lane := {
			"arm_a": str(e["arm_name"]),
			"arm_b": str(e["arm_name"]),
			"rest_local_a": e["rest_local"],
			"rest_local_b": e["rest_local"],
			"socket_a": e["socket"],
			"socket_b": e["socket"],
			"balls": [_make_ball_state(e["item"], str(e["arm_name"]), e["socket"], e["rest_local"])],
		}
		_lanes.append(lane)
		_configure_lane_ball_timing(lane)


func _build_cycle_lane_from_ball_entries(ball_entries: Array) -> void:
	_lanes.clear()
	var arm_points: Dictionary = {}
	var cycle_arms: Array[String] = []
	for e in ball_entries:
		var arm_name := str(e["arm_name"])
		if arm_name.is_empty():
			continue
		if not arm_points.has(arm_name):
			arm_points[arm_name] = {
				"socket": e["socket"],
				"rest_local": e["rest_local"],
			}
			cycle_arms.append(arm_name)
	if cycle_arms.size() < 2:
		_build_lanes_from_ball_entries(ball_entries)
		return
	cycle_arms.sort()
	var balls: Array = []
	for i in range(ball_entries.size()):
		var e: Dictionary = ball_entries[i]
		var b := _make_ball_state(e["item"], str(e["arm_name"]), e["socket"], e["rest_local"])
		b["cycle_start_idx"] = i % cycle_arms.size()
		b["start_delay"] = beat_duration * (float(i) / maxf(1.0, float(ball_entries.size())))
		balls.append(b)
	_lanes.append({
		"arm_cycle": cycle_arms,
		"arm_points": arm_points,
		"balls": balls,
	})


func _configure_lane_ball_timing(lane: Dictionary) -> void:
	if lane.has("arm_cycle"):
		return
	var balls: Array = lane["balls"]
	var count := balls.size()
	if count <= 0:
		return
	var is_self_toss: bool = (str(lane["arm_a"]) == str(lane["arm_b"]))
	if is_self_toss:
		for b in balls:
			b["start_delay"] = 0.0
			b["start_from_a"] = true
		return

	# 2-ball cross pattern:
	# ball 0 tosses A->B immediately, ball 1 tosses B->A at apex (half beat).
	for i in range(count):
		var b: Dictionary = balls[i]
		if i == 0:
			b["start_delay"] = 0.0
			b["start_from_a"] = true
		else:
			b["start_delay"] = beat_duration * 0.5
			b["start_from_a"] = false


# ---------------------------------------------------------------------------
# Ball position
# ---------------------------------------------------------------------------

func _update_ball_position(ball_state: Dictionary, lane: Dictionary) -> void:
	var item: Node = ball_state["item"]
	if item == null or not is_instance_valid(item):
		return
	var pickup_root: Node3D = item.get_pickup_root()
	if pickup_root == null:
		return
	if total_time < 0.0:
		return

	if bool(ball_state.get("retired", false)):
		pickup_root.global_position = _get_retired_ball_hold_position(ball_state, lane)
		return

	var active_time := maxf(total_time, 0.0)
	if _stop_requested and bool(ball_state.get("retire_on_catch", false)):
		if lane.has("arm_cycle"):
			_try_retire_cycle_ball(active_time, ball_state, lane)
		else:
			_try_retire_non_cycle_ball(active_time, ball_state, lane)
		if bool(ball_state.get("retired", false)):
			pickup_root.global_position = _get_retired_ball_hold_position(ball_state, lane)
			return
	pickup_root.global_position = _compute_ball_position(active_time, ball_state, lane)


func _request_all_balls_retire_on_catch() -> void:
	for lane in _lanes:
		for ball_state in lane["balls"]:
			ball_state["retire_on_catch"] = true


func _all_balls_retired() -> bool:
	for lane in _lanes:
		for ball_state in lane["balls"]:
			if not bool(ball_state.get("retired", false)):
				return false
	return true


func _try_retire_non_cycle_ball(active_time: float, ball_state: Dictionary, lane: Dictionary) -> void:
	var start_delay := float(ball_state.get("start_delay", 0.0))
	var start_from_a := bool(ball_state.get("start_from_a", true))
	var item: Node = ball_state.get("item", null)
	var assigned_arm := str(ball_state.get("arm_name", ""))
	if active_time < start_delay:
		ball_state["retired"] = true
		ball_state["retired_arm"] = _resolve_retire_arm([assigned_arm, str(lane["arm_a"]), str(lane["arm_b"])], item)
		_record_ball_arm_assignment(item, str(ball_state["retired_arm"]))
		return
	var phase := (active_time - start_delay) / maxf(0.001, beat_duration)
	var beat_index := int(floor(phase))
	var t := fmod(phase, 1.0)
	var even_beat := (beat_index % 2) == 0
	var from_a := start_from_a if even_beat else not start_from_a
	var catch_arm := str(lane["arm_b"]) if from_a else str(lane["arm_a"])
	var other_arm := str(lane["arm_a"]) if from_a else str(lane["arm_b"])
	var seen_beat := int(ball_state.get("retire_seen_beat", -1))
	if seen_beat < 0:
		ball_state["retire_seen_beat"] = beat_index
		seen_beat = beat_index
	# Retire on catch robustly: either near arc end, or we crossed beat boundary
	# between frames and missed t>=0.98.
	if t >= 0.98 or beat_index > seen_beat:
		ball_state["retired"] = true
		ball_state["retired_arm"] = _resolve_retire_arm([assigned_arm, catch_arm, other_arm], item)
		_record_ball_arm_assignment(item, str(ball_state["retired_arm"]))
		return
	ball_state["retire_seen_beat"] = beat_index


func _try_retire_cycle_ball(active_time: float, ball_state: Dictionary, lane: Dictionary) -> void:
	var arm_cycle: Array = lane.get("arm_cycle", [])
	var arm_count := arm_cycle.size()
	var item: Node = ball_state.get("item", null)
	var assigned_arm := str(ball_state.get("arm_name", ""))
	if arm_count < 2:
		ball_state["retired"] = true
		ball_state["retired_arm"] = _resolve_retire_arm([assigned_arm], item)
		_record_ball_arm_assignment(item, str(ball_state["retired_arm"]))
		return
	var start_delay := float(ball_state.get("start_delay", 0.0))
	var start_idx := int(ball_state.get("cycle_start_idx", 0)) % arm_count
	if active_time < start_delay:
		ball_state["retired"] = true
		var cycle_pref: Array[String] = []
		if not assigned_arm.is_empty():
			cycle_pref.append(assigned_arm)
		for k in range(arm_count):
			cycle_pref.append(str(arm_cycle[(start_idx + k) % arm_count]))
		ball_state["retired_arm"] = _resolve_retire_arm(cycle_pref, item)
		_record_ball_arm_assignment(item, str(ball_state["retired_arm"]))
		return
	var phase := (active_time - start_delay) / maxf(0.001, beat_duration)
	var beat_index := int(floor(phase))
	var t := fmod(phase, 1.0)
	var from_idx := (start_idx + beat_index) % arm_count
	var to_idx := (from_idx + 1) % arm_count
	var seen_beat := int(ball_state.get("retire_seen_beat", -1))
	if seen_beat < 0:
		ball_state["retire_seen_beat"] = beat_index
		seen_beat = beat_index
	if t >= 0.98 or beat_index > seen_beat:
		ball_state["retired"] = true
		var cycle_pref: Array[String] = []
		if not assigned_arm.is_empty():
			cycle_pref.append(assigned_arm)
		for k in range(arm_count):
			cycle_pref.append(str(arm_cycle[(to_idx + k) % arm_count]))
		ball_state["retired_arm"] = _resolve_retire_arm(cycle_pref, item)
		_record_ball_arm_assignment(item, str(ball_state["retired_arm"]))
		return
	ball_state["retire_seen_beat"] = beat_index


func _resolve_retire_arm(preferred_arms: Array[String], item: Node) -> String:
	var occupied := _collect_retired_arms(item)
	for arm_name in preferred_arms:
		if arm_name.is_empty():
			continue
		if _blocked_arms.has(arm_name):
			continue
		if not occupied.has(arm_name):
			return arm_name
	for arm_name in preferred_arms:
		if not arm_name.is_empty() and not _blocked_arms.has(arm_name):
			return arm_name
	return ""


func _collect_blocked_arms_from_held_items(
	held_items: Array,
	held_socket_by_item_id: Dictionary,
	arm_name_by_socket_index: Dictionary
) -> Dictionary:
	var blocked: Dictionary = {}
	for held_item in held_items:
		if held_item == null or not is_instance_valid(held_item):
			continue
		if _is_ball(held_item):
			continue
		var item_id: int = held_item.get_instance_id()
		var socket_idx := int(held_socket_by_item_id.get(item_id, -1))
		var arm_name := str(arm_name_by_socket_index.get(socket_idx, ""))
		if not arm_name.is_empty():
			blocked[arm_name] = true
	return blocked


func _collect_retired_arms(exclude_item: Node) -> Dictionary:
	var occupied: Dictionary = {}
	for lane in _lanes:
		for bs in lane["balls"]:
			if not bool(bs.get("retired", false)):
				continue
			var bs_item: Node = bs.get("item", null)
			if bs_item == exclude_item:
				continue
			var arm_name := str(bs.get("retired_arm", ""))
			if arm_name.is_empty():
				continue
			occupied[arm_name] = true
	return occupied


func _get_retired_ball_hold_position(ball_state: Dictionary, lane: Dictionary) -> Vector3:
	var arm_name := str(ball_state.get("retired_arm", ""))
	if arm_name.is_empty():
		arm_name = str(ball_state.get("arm_name", ""))
	if lane.has("arm_cycle"):
		return _get_cycle_arm_anchor_world(lane, arm_name, ball_state)
	if arm_name == str(lane["arm_b"]):
		return _get_lane_anchor_world(lane, "b")
	return _get_lane_anchor_world(lane, "a")


func _refresh_lane_rest_anchors_from_held_items() -> void:
	if _player == null:
		return
	for lane in _lanes:
		var balls: Array = lane["balls"]
		for ball_state in balls:
			var item: Node = ball_state["item"]
			if item == null or not is_instance_valid(item):
				continue
			var pickup_root: Node3D = item.get_pickup_root()
			if pickup_root == null:
				continue
			var rest_local := _player.to_local(pickup_root.global_position)
			lane["rest_local_a"] = rest_local
			lane["rest_local_b"] = rest_local
			break


func _compute_ball_position(active_time: float, ball_state: Dictionary, lane: Dictionary) -> Vector3:
	if lane.has("arm_cycle"):
		return _compute_cycle_ball_position(active_time, ball_state, lane)

	var is_self_toss: bool = (str(lane["arm_a"]) == str(lane["arm_b"]))
	var pos_a: Vector3 = _get_lane_anchor_world(lane, "a")
	var pos_b: Vector3 = pos_a if is_self_toss else _get_lane_anchor_world(lane, "b")

	var start_delay := float(ball_state.get("start_delay", 0.0))
	var start_from_a := bool(ball_state.get("start_from_a", true))

	if active_time < start_delay:
		return pos_a if start_from_a else pos_b

	var phase := (active_time - start_delay) / maxf(0.001, beat_duration)
	var beat_index := int(floor(phase))
	var t := fmod(phase, 1.0)

	var even_beat := (beat_index % 2) == 0
	var from_a := start_from_a if even_beat else not start_from_a

	var from_pos := pos_a if from_a else pos_b
	var to_pos := pos_b if from_a else pos_a
	var base_pos := from_pos.lerp(to_pos, smoothstep(0.0, 1.0, t))

	var height := lane_arc_height if not is_self_toss else arc_height
	var arc_y := height * sin(PI * t)

	var fwd_amount := lane_forward_offset if not is_self_toss else forward_offset
	var forward := -_player.global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()

	return base_pos + Vector3(0.0, arc_y, 0.0) + forward * (sin(PI * t) * fwd_amount)


func _compute_cycle_ball_position(active_time: float, ball_state: Dictionary, lane: Dictionary) -> Vector3:
	var arm_cycle: Array = lane.get("arm_cycle", [])
	var arm_count := arm_cycle.size()
	if arm_count < 2:
		var arm_name := str(ball_state.get("arm_name", ""))
		return _get_cycle_arm_anchor_world(lane, arm_name, ball_state)

	var start_delay := float(ball_state.get("start_delay", 0.0))
	var start_idx := int(ball_state.get("cycle_start_idx", 0)) % arm_count
	if active_time < start_delay:
		return _get_cycle_arm_anchor_world(lane, str(arm_cycle[start_idx]), ball_state)

	var phase := (active_time - start_delay) / maxf(0.001, beat_duration)
	var beat_index := int(floor(phase))
	var t := fmod(phase, 1.0)
	var from_idx := (start_idx + beat_index) % arm_count
	var to_idx := (from_idx + 1) % arm_count
	var from_arm := str(arm_cycle[from_idx])
	var to_arm := str(arm_cycle[to_idx])
	var from_pos := _get_cycle_arm_anchor_world(lane, from_arm, ball_state)
	var to_pos := _get_cycle_arm_anchor_world(lane, to_arm, ball_state)
	var base_pos := from_pos.lerp(to_pos, smoothstep(0.0, 1.0, t))
	var arc_y := lane_arc_height * sin(PI * t)
	var forward := -_player.global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	return base_pos + Vector3(0.0, arc_y, 0.0) + forward * (sin(PI * t) * lane_forward_offset)


func _get_cycle_arm_anchor_world(lane: Dictionary, arm_name: String, ball_state: Dictionary) -> Vector3:
	var arm_points: Dictionary = lane.get("arm_points", {})
	if not arm_points.has(arm_name):
		return _player.global_position
	var point: Dictionary = arm_points[arm_name]
	var socket := point.get("socket", null) as Node3D
	var rest_local := point.get("rest_local", Vector3.ZERO) as Vector3
	var fallback := _player.to_global(rest_local)
	if socket == null or not is_instance_valid(socket):
		return fallback
	var item: Node = ball_state.get("item", null)
	if item != null and is_instance_valid(item) and item.has_method("get_hold_transform"):
		var hold_tf: Transform3D = item.get_hold_transform()
		return (socket.global_transform * hold_tf).origin
	return socket.global_position


func _get_lane_anchor_world(lane: Dictionary, side: String) -> Vector3:
	var rest_key := "rest_local_a" if side == "a" else "rest_local_b"
	var socket_key := "socket_a" if side == "a" else "socket_b"
	var fallback := _player.to_global(lane[rest_key] as Vector3)
	if not lane.has(socket_key):
		return fallback
	var socket := lane[socket_key] as Node3D
	if socket == null or not is_instance_valid(socket):
		return fallback
	var item := _first_valid_lane_item(lane)
	if item == null:
		return socket.global_position
	if item.has_method("get_hold_transform"):
		var hold_tf: Transform3D = item.get_hold_transform()
		return (socket.global_transform * hold_tf).origin
	return socket.global_position


func _first_valid_lane_item(lane: Dictionary) -> Node:
	var balls: Array = lane.get("balls", [])
	for ball_state in balls:
		var item: Node = ball_state.get("item", null)
		if item != null and is_instance_valid(item):
			return item
	return null


# ---------------------------------------------------------------------------
# Tip-bend gesture (tip only, no whole-arm animation)
# ---------------------------------------------------------------------------

const _TOSS_PHASE  := 0.05
const _CATCH_PHASE := 0.80

func _check_gestures(ball_state: Dictionary, lane: Dictionary) -> void:
	if bool(ball_state.get("retired", false)):
		return
	if lane.has("arm_cycle"):
		_check_cycle_gestures(ball_state, lane)
		return

	var active_time := maxf(total_time, 0.0)
	var start_delay := float(ball_state.get("start_delay", 0.0))
	if active_time < start_delay:
		return

	var phase := (active_time - start_delay) / maxf(0.001, beat_duration)
	var beat_index := int(floor(phase))
	var t := fmod(phase, 1.0)
	var start_from_a := bool(ball_state.get("start_from_a", true))
	var even_beat := (beat_index % 2) == 0
	var from_a := start_from_a if even_beat else not start_from_a
	var toss_arm := str(lane["arm_a"]) if from_a else str(lane["arm_b"])
	var catch_arm := str(lane["arm_b"]) if from_a else str(lane["arm_a"])

	if beat_index > int(ball_state["last_beat"]):
		ball_state["last_beat"] = beat_index
		ball_state["toss_fired"] = false
		ball_state["catch_fired"] = false

	if t < _TOSS_PHASE and not bool(ball_state["toss_fired"]):
		ball_state["toss_fired"] = true
		_start_tip_pulse(toss_arm)

	if t > _CATCH_PHASE and not bool(ball_state["catch_fired"]):
		ball_state["catch_fired"] = true
		_start_tip_pulse(catch_arm)


func _check_cycle_gestures(ball_state: Dictionary, lane: Dictionary) -> void:
	var active_time := maxf(total_time, 0.0)
	var start_delay := float(ball_state.get("start_delay", 0.0))
	if active_time < start_delay:
		return
	var arm_cycle: Array = lane.get("arm_cycle", [])
	var arm_count := arm_cycle.size()
	if arm_count < 2:
		return
	var phase := (active_time - start_delay) / maxf(0.001, beat_duration)
	var beat_index := int(floor(phase))
	var t := fmod(phase, 1.0)
	var start_idx := int(ball_state.get("cycle_start_idx", 0)) % arm_count
	var from_idx := (start_idx + beat_index) % arm_count
	var to_idx := (from_idx + 1) % arm_count
	var toss_arm := str(arm_cycle[from_idx])
	var catch_arm := str(arm_cycle[to_idx])

	if beat_index > int(ball_state["last_beat"]):
		ball_state["last_beat"] = beat_index
		ball_state["toss_fired"] = false
		ball_state["catch_fired"] = false

	if t < _TOSS_PHASE and not bool(ball_state["toss_fired"]):
		ball_state["toss_fired"] = true
		_start_tip_pulse(toss_arm)

	if t > _CATCH_PHASE and not bool(ball_state["catch_fired"]):
		ball_state["catch_fired"] = true
		_start_tip_pulse(catch_arm)


func _start_tip_pulse(arm_name: String) -> void:
	if not _tip_state.has(arm_name):
		_tip_state[arm_name] = { "value": 0.0, "target": 0.0, "hold": 0.0 }
	var s: Dictionary = _tip_state[arm_name]
	s["target"] = juggle_tip_bend_amount
	s["hold"]   = juggle_tip_hold_time


## Advance all tip springs and push current value to OctoRig each frame.
## Rise is fast (snappy toss/catch feel); fall is slow (no abrupt snap back).
func _update_tip_pulses(delta: float) -> void:
	if _octo_rig == null or not _octo_rig.has_method("set_juggle_tip_bend"):
		return
	var done: Array = []
	for arm_name in _tip_state.keys():
		var s: Dictionary = _tip_state[arm_name]
		var current: float = float(s["value"])
		var target:  float = float(s["target"])

		# Hold at peak before releasing.
		if target > 0.0:
			s["hold"] = float(s["hold"]) - delta
			if float(s["hold"]) <= 0.0:
				s["target"] = 0.0
				target = 0.0

		# Exponential lerp: different speeds for rising vs falling.
		var speed: float = juggle_tip_rise_speed if target > current else juggle_tip_fall_speed
		var new_val: float = lerpf(current, target, 1.0 - exp(-speed * delta))
		s["value"] = new_val
		_octo_rig.set_juggle_tip_bend(arm_name, new_val)

		# Clean up once fully returned to rest.
		if target == 0.0 and new_val < 0.002:
			done.append(arm_name)

	for arm_name in done:
		_tip_state.erase(arm_name)
		_octo_rig.set_juggle_tip_bend(arm_name, 0.0)


# ---------------------------------------------------------------------------
# Ball identity
# ---------------------------------------------------------------------------

func _is_ball(item: Node) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	if not item.has_method("get_pickup_root"):
		return false
	var pickup_root: Node = item.get_pickup_root()
	if pickup_root == null:
		return false
	return pickup_root.get_script() == TheBallScript
