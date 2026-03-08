extends RefCounted
class_name InteractionHintBuilder


func build_lines(context: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var focus_locked: bool = bool(context.get("focus_locked", false))
	if focus_locked:
		lines.append_array([
			"LMB Interact",
			"RMB Exit Focus",
			"Esc In-Game Menu"
		])
	else:
		lines.append_array([
			"LMB Move / Interact",
			"RMB + Drag Orbit",
			"Q/E Keyboard Orbit",
			"Mouse Wheel Zoom",
			"F Drop Last Item",
			"Shift+F Drop All Items",
			"Esc In-Game Menu"
		])

	var hovered_name: String = str(context.get("hovered_name", ""))
	if not hovered_name.is_empty():
		var hovered_is_held: bool = bool(context.get("hovered_is_held", false))
		var hovered_blocked: bool = bool(context.get("hovered_blocked", false))
		var hovered_in_range: bool = bool(context.get("hovered_in_range", false))
		var hovered_prompt: String = str(context.get("hovered_prompt", "Interact"))
		if hovered_is_held:
			if focus_locked:
				lines.append("LMB Select %s" % hovered_name)
			else:
				lines.append("LMB Drop %s" % hovered_name)
		elif hovered_blocked:
			lines.append("Blocked: %s" % hovered_name)
		elif hovered_in_range:
			lines.append("LMB %s %s" % [hovered_prompt, hovered_name])
		else:
			lines.append("%s is out of range" % hovered_name)
			lines.append("LMB Move Closer")

	var held_count := int(context.get("held_count", 0))
	var max_held := int(context.get("max_held", 0))
	lines.append("Held: %d/%d" % [held_count, max_held])

	var immobilized_at := int(context.get("immobilized_at", 0))
	var slow_at := int(context.get("slow_at", 0))
	if held_count >= immobilized_at:
		lines.append("Overloaded: cannot move")
	elif held_count >= slow_at:
		lines.append("Heavy carry: movement slowed")

	var queued_target_name: String = str(context.get("queued_target_name", ""))
	if not queued_target_name.is_empty():
		lines.append("Auto-interact queued: %s" % queued_target_name)

	var awaiting_card_selection: bool = bool(context.get("awaiting_card_selection", false))
	if awaiting_card_selection:
		lines.append("Card Reader: choose held card (click card in hands)")

	return lines
