extends Node3D

func _ready() -> void:
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	var anims := player.get_animation_list()
	if anims.is_empty():
		return
	var anim_name := anims[0]
	var anim := player.get_animation(anim_name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR
	player.play(anim_name)
