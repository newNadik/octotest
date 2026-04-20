extends SceneTree


const CARD_READER_SCENE: PackedScene = preload("res://scenes/interactables/card_reader.tscn")
const CardReaderScript = preload("res://scripts/interaction/card_reader.gd")


class MockCard:
	extends Node3D

	var item_id: String
	var _is_card_flag: bool
	var interaction_enabled := true

	func _init(new_item_id: String, is_card_flag: bool = true) -> void:
		item_id = new_item_id
		_is_card_flag = is_card_flag

	func is_card() -> bool:
		return _is_card_flag

	func set_interaction_enabled(enabled: bool) -> void:
		interaction_enabled = enabled

	func get_pickup_root() -> Node3D:
		return self

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var reader_node: Node = CARD_READER_SCENE.instantiate()
	root.add_child(reader_node)

	await process_frame

	var reader: CardReaderScript = reader_node as CardReaderScript
	_expect_true(reader != null, "card reader scene should instantiate CardReader")
	if reader == null:
		_finish(reader_node)
		return

	var required_card_id: String = String(reader.required_card_id)
	var correct_card := MockCard.new(required_card_id, true)
	var wrong_card := MockCard.new("card_wrong", true)
	var non_card := MockCard.new("not_a_card", false)
	root.add_child(correct_card)
	root.add_child(wrong_card)
	root.add_child(non_card)

	_expect_true(reader.can_accept_card(correct_card), "reader should accept a card when empty")
	_expect_true(not reader.can_accept_card(non_card), "reader should reject non-card object")

	_expect_true(reader.insert_card(wrong_card), "reader should insert wrong card")
	_expect_true(reader.has_inserted_card(), "reader should report inserted card")
	_expect_true(not reader.is_correct_card_inserted(), "wrong card should not set correct state")
	_expect_true(not reader.can_accept_card(correct_card), "reader should reject second card while occupied")

	var ejected_wrong = reader.eject_card()
	_expect_true(ejected_wrong == wrong_card, "eject should return inserted wrong card")
	_expect_true(not reader.has_inserted_card(), "reader should be empty after eject")
	_expect_true(wrong_card.interaction_enabled, "ejected card should remain interactable")

	_expect_true(reader.insert_card(correct_card), "reader should insert required card id")
	_expect_true(reader.is_correct_card_inserted(), "required card should set correct state")
	var ejected_correct = reader.eject_card()
	_expect_true(ejected_correct == correct_card, "eject should return inserted correct card")
	_expect_true(not reader.has_inserted_card(), "reader should be empty after ejecting correct card")

	_expect_true(reader.can_accept_card(correct_card), "reader should accept card again after eject")

	_finish(reader_node)


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
