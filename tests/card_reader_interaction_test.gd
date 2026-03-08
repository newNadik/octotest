extends SceneTree


const MAIN_SCENE = preload("res://scenes/main.tscn")
const SETTLE_FRAMES := 4

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)

	for i in range(SETTLE_FRAMES):
		await physics_frame

	var controller := world.get_node_or_null("InteractionController")
	var reader := world.get_node_or_null("Interactables/CardReader")
	var focus_target := world.get_node_or_null("Interactables/CardReader/FocusTarget")
	var camera := world.get_node_or_null("CameraPivot/CameraYaw/CameraPitch/SpringArm3D/Camera3D") as Camera3D
	var card_a := world.get_node_or_null("Interactables/Card/Interactable")
	var card_b := world.get_node_or_null("Interactables/Card2/Interactable")

	_expect_true(controller != null, "interaction controller should exist")
	_expect_true(reader != null, "card reader should exist")
	_expect_true(focus_target != null, "focus target should exist")
	_expect_true(camera != null, "camera should exist")
	_expect_true(card_a != null and card_b != null, "card interactables should exist")
	if _failures > 0:
		_finish(world)
		return

	_expect_true(bool(controller.call("_attach_item_to_hands", card_a, false)), "card A should attach to hands")
	controller.call("_handle_card_reader_click", reader)
	_expect_true(reader.has_inserted_card(), "reader should contain inserted card after click handling")
	_expect_true(controller.get_held_item_names().size() == 0, "held list should be empty after inserting only held card")

	_expect_true(bool(controller.call("_attach_item_to_hands", card_b, false)), "card B should attach to hands")
	_expect_true(not reader.can_accept_card(card_b), "reader should reject additional card while occupied")

	controller.set_focus_locked(true)
	controller.set_focus_display(true, camera)
	controller.set_focus_target(focus_target)
	controller.process_interactions(1.0 / 60.0)

	var card_b_screen := camera.unproject_position(card_b.get_pickup_root().global_position)
	controller.try_handle_interaction_click(card_b_screen)
	_expect_true(reader.has_inserted_card(), "clicking held card should not replace inserted card")
	_expect_true(controller.get_held_item_names().size() == 1, "held card should remain held when reader is occupied")

	controller.call("_handle_card_reader_click", reader)
	_expect_true(not reader.has_inserted_card(), "reader should eject inserted card on click")
	_expect_true(controller.get_held_item_names().size() == 2, "both cards should be held after eject")

	controller.set_focus_locked(false)
	controller.set_focus_display(false, null)
	controller.set_focus_target(null)

	_finish(world)


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
		print("card_reader_interaction_test: PASS")
		quit(0)
		return

	printerr("card_reader_interaction_test: FAIL (%d failures)" % _failures)
	quit(1)
