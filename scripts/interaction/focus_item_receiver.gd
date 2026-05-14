extends RefCounted
class_name FocusItemReceiver

enum ApplyResult {
	NO_TARGET,
	FOCUS_UNLOCKED,
	ITEM_NOT_HELD,
	REJECTED,
	APPLIED_KEEP,
	APPLIED_CONSUME,
}


func apply(item, focus_behavior, is_focus_locked: bool, is_item_held: bool) -> ApplyResult:
	if item == null or focus_behavior == null:
		return ApplyResult.NO_TARGET
	if not is_focus_locked:
		return ApplyResult.FOCUS_UNLOCKED
	if not is_item_held:
		return ApplyResult.ITEM_NOT_HELD

	var can_receive: bool = focus_behavior.can_receive_item(item)
	var applied: bool = can_receive and focus_behavior.receive_item(item)
	if not applied:
		return ApplyResult.REJECTED

	if focus_behavior.should_consume_received_item(item):
		return ApplyResult.APPLIED_CONSUME
	return ApplyResult.APPLIED_KEEP
