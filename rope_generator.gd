@tool
extends Node3D

## LanyardGenerator
## A single flat strap loop — one bone chain, ribbon-shaped mesh.
## Requires Godot 4.3+

@export_group("Strap Shape")
## Number of bones in the chain (more = smoother drape)
@export var bone_count: int = 12:
	set(v): bone_count = clamp(v, 2, 32)

## Length of each bone segment
@export var bone_length: float = 0.10:
	set(v): bone_length = max(0.01, v)

## Width of the flat strap (across X) — e.g. 0.025 = 2.5cm
@export var strap_width: float = 0.025:
	set(v): strap_width = max(0.001, v)

## Thickness of the strap (along Z) — e.g. 0.002 = 2mm
@export var strap_thickness: float = 0.002:
	set(v): strap_thickness = max(0.0001, v)

@export_group("Visual")
@export var strap_color: Color = Color(0.05, 0.05, 0.05)  # near-black
@export var show_clip: bool = true

@export_group("Actions")
@export var generate: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_generate()
		generate = false

@export var clear: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_clear_children()
		clear = false


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

func _generate() -> void:
	_clear_children()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = strap_color if strap_color != null else Color(0.05, 0.05, 0.05)
	mat.roughness = 0.8
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # visible from both sides

	var skeleton := _build_skeleton()
	_build_visual_mesh(skeleton, mat)
	_build_spring_simulator(skeleton)
	if show_clip:
		_build_clip(skeleton)

	print("[LanyardGenerator] Done — %d bones." % bone_count)
	print("  SpringBoneSimulator3D → Bone Chains:")
	print("    Root Bone = %s   End Bone = %s" % [_bone_name(0), _bone_name(bone_count - 1)])
	print("  Set Gravity = 9.8, Direction = (0,-1,0)")


func _clear_children() -> void:
	for child in get_children():
		child.free()


# ---------------------------------------------------------------------------
# Skeleton — single straight chain
# ---------------------------------------------------------------------------

func _build_skeleton() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "LanyardSkeleton"
	add_child(skeleton)
	skeleton.owner = _get_owner()

	for i in range(bone_count):
		var bone_idx := skeleton.add_bone(_bone_name(i))
		if i > 0:
			skeleton.set_bone_parent(bone_idx, bone_idx - 1)
		var rest := Transform3D()
		if i > 0:
			rest.origin = Vector3(0.0, -bone_length, 0.0)
		skeleton.set_bone_rest(bone_idx, rest)

	skeleton.reset_bone_poses()
	return skeleton


# ---------------------------------------------------------------------------
# Visual mesh — flat box (ribbon) per bone segment
# ---------------------------------------------------------------------------

func _build_visual_mesh(skeleton: Skeleton3D, mat: StandardMaterial3D) -> void:
	for i in range(bone_count - 1):
		var attachment := BoneAttachment3D.new()
		attachment.name = "Attach_%02d" % i
		attachment.bone_name = _bone_name(i)
		skeleton.add_child(attachment)
		attachment.owner = _get_owner()

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Seg_%02d" % i

		# Flat ribbon: wide on X, long on Y (bone axis), thin on Z
		var box := BoxMesh.new()
		box.size = Vector3(strap_width, bone_length, strap_thickness)
		mesh_instance.mesh = box
		mesh_instance.material_override = mat
		# Centre between this bone and next
		mesh_instance.position = Vector3(0.0, -bone_length * 0.5, 0.0)

		attachment.add_child(mesh_instance)
		mesh_instance.owner = _get_owner()


# ---------------------------------------------------------------------------
# SpringBoneSimulator3D
# ---------------------------------------------------------------------------

func _build_spring_simulator(skeleton: Skeleton3D) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "SpringBoneSimulator3D"
	skeleton.add_child(sim)
	sim.owner = _get_owner()

	# Floor collision — keep pinned to world zero in _process()
	var plane := SpringBoneCollisionPlane3D.new()
	plane.name = "FloorCollision"
	sim.add_child(plane)
	plane.owner = _get_owner()

	# Configure in inspector after generating:
	#   Bone Chains → [0]
	#     Root Bone = Bone_00
	#     End Bone  = Bone_11  (bone_count - 1)
	#     Gravity   = 9.8
	#     Direction = (0, -1, 0)
	#     Stiffness = 0.0
	#     Damping   = 0.6


# ---------------------------------------------------------------------------
# Clip — metal hook at the bottom
# ---------------------------------------------------------------------------

func _build_clip(skeleton: Skeleton3D) -> void:
	var clip_mat := StandardMaterial3D.new()
	clip_mat.albedo_color = Color(0.75, 0.75, 0.75)
	clip_mat.metallic = 0.9
	clip_mat.roughness = 0.2

	# Main clip body
	var attachment := BoneAttachment3D.new()
	attachment.name = "ClipAttach"
	attachment.bone_name = _bone_name(bone_count - 1)
	skeleton.add_child(attachment)
	attachment.owner = _get_owner()

	var clip_mesh := MeshInstance3D.new()
	clip_mesh.name = "Clip"
	var box := BoxMesh.new()
	# Clip is wider than strap, short, and thick like a real lanyard clip
	box.size = Vector3(strap_width * 1.2, strap_width * 0.8, strap_width * 0.4)
	clip_mesh.mesh = box
	clip_mesh.material_override = clip_mat
	clip_mesh.position = Vector3(0.0, -strap_width * 0.4, 0.0)
	attachment.add_child(clip_mesh)
	clip_mesh.owner = _get_owner()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _bone_name(i: int) -> String:
	return "Bone_%02d" % i

func _get_owner() -> Node:
	return owner if owner else self
