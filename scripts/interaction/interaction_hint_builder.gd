extends RefCounted
class_name InteractionHintBuilder


func build_lines(context: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var focus_locked: bool = bool(context.get("focus_locked", false))
	if focus_locked:
		lines.append_array([
			tr("LMB Interact"),
			tr("LMB Drag Orbit"),
			tr("Esc In-Game Menu")
		])
	else:
		lines.append_array([
			tr("LMB Move / Interact"),
			tr("LMB Drag Orbit"),
			tr("Mouse Wheel Zoom"),
			tr("Esc In-Game Menu")
		])

	var hovered_name: String = str(context.get("hovered_name", ""))
	if not hovered_name.is_empty():
		var hovered_is_held: bool = bool(context.get("hovered_is_held", false))
		var hovered_blocked: bool = bool(context.get("hovered_blocked", false))
		var hovered_in_range: bool = bool(context.get("hovered_in_range", false))
		var hovered_prompt: String = str(context.get("hovered_prompt", "Interact"))
		var translated_name := tr(hovered_name)
		var translated_prompt := tr(hovered_prompt)
		if hovered_is_held:
			if focus_locked:
				lines.append(tr("LMB Select %s") % translated_name)
			else:
				lines.append(tr("LMB Drop %s") % translated_name)
		elif hovered_blocked:
			lines.append(tr("Blocked: %s") % translated_name)
		elif hovered_in_range:
			lines.append(tr("LMB %s %s") % [translated_prompt, translated_name])
		else:
			lines.append(tr("%s is out of range") % translated_name)
			lines.append(tr("LMB Move Closer"))

	var held_count := int(context.get("held_count", 0))
	var max_held := int(context.get("max_held", 0))
	lines.append(tr("Held: %d/%d") % [held_count, max_held])

	var immobilized_at := int(context.get("immobilized_at", 0))
	var slow_at := int(context.get("slow_at", 0))
	if held_count >= immobilized_at:
		lines.append(tr("Overloaded: cannot move"))
	elif held_count >= slow_at:
		lines.append(tr("Heavy carry: movement slowed"))

	var queued_target_name: String = str(context.get("queued_target_name", ""))
	if not queued_target_name.is_empty():
		lines.append(tr("Auto-interact queued: %s") % tr(queued_target_name))

	var awaiting_card_selection: bool = bool(context.get("awaiting_card_selection", false))
	if awaiting_card_selection:
		lines.append(tr("Card reader: choose a held card (click a card in hands)"))

	return lines
