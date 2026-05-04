extends Node3D
class_name InteractionBehavior

# Override to respond to a click interaction from the player.
func on_interacted(_actor: Node) -> void:
	pass

# Override to declare whether this behavior can accept a held item (used in focus mode).
func can_receive_item(_item: Interactable) -> bool:
	return false

# Override to apply the held item. Return true on success.
func receive_item(_item: Interactable) -> bool:
	return false

# Override to control whether a successful item application should consume
# (remove and free) the held item from the player's inventory.
func should_consume_received_item(_item: Interactable) -> bool:
	return true
