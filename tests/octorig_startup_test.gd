extends SceneTree


const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const OctoRigScript = preload("res://scripts/rig/OctoRig.gd")
const SETTLE_FRAMES := 3

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_root: Node = PLAYER_SCENE.instantiate()
	root.add_child(player_root)

	for i in range(SETTLE_FRAMES):
		await process_frame

	var player: CharacterBody3D = player_root as CharacterBody3D
	_expect_true(player != null, "player scene root should be CharacterBody3D")

	var visual_root: Node = player_root.get_node_or_null("PlayerVisual")
	_expect_true(visual_root != null, "player should contain PlayerVisual")
	_expect_true(visual_root is OctoRigScript, "PlayerVisual should use OctoRig script")

	if visual_root is OctoRigScript:
		var octo_rig: OctoRigScript = visual_root as OctoRigScript
		_expect_true(octo_rig.has_valid_setup(), "OctoRig should build valid setup at game start")
		_expect_true(octo_rig.skeleton != null, "OctoRig should resolve skeleton at game start")
		_expect_true(octo_rig.arms.size() == 8, "OctoRig should initialize 8 arms")
		var all_arm_bones: Array[int] = octo_rig.get_all_arm_bones()
		_expect_true(all_arm_bones.size() > 0, "OctoRig should resolve weighted arm bones")

	_finish(player_root)


func _expect_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: ", message)


func _finish(world: Node) -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
		await process_frame

	if _failures == 0:
		print("octorig_startup_test: PASS")
		quit(0)
		return

	printerr("octorig_startup_test: FAIL (%d failures)" % _failures)
	quit(1)
