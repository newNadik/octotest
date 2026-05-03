@tool
extends Node3D

## LanyardGenerator
## Generates a skinned flat ribbon mesh driven by a single bone chain.
## Assign a texture in the inspector after generating.
## Requires Godot 4.3+

@export_group("Strap Shape")
@export var bone_count: int = 12:
	set(v): bone_count = clamp(v, 2, 32)

@export var bone_length: float = 0.10:
	set(v): bone_length = max(0.01, v)

## Width of the flat strap
@export var strap_width: float = 0.025:
	set(v): strap_width = max(0.001, v)

@export_group("Visual")
@export var strap_color: Color = Color(0.05, 0.05, 0.05)
## Assign your lanyard texture here — applied along the ribbon length
@export var strap_texture: Texture2D

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

	var skeleton := _build_skeleton()
	_build_skinned_mesh(skeleton)
	_build_spring_simulator(skeleton)

	print("[LanyardGenerator] Done — %d bones, skinned ribbon mesh." % bone_count)
	print("  Configure SpringBoneSimulator3D in inspector:")
	print("    Root=%s  End=%s  Gravity=9.8  Dir=(0,-1,0)" % [
		_bone_name(0), _bone_name(bone_count - 1)
	])


func _clear_children() -> void:
	for child in get_children():
		child.free()


# ---------------------------------------------------------------------------
# Skeleton
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
# Skinned ribbon mesh
#
# Vertex layout — two verts per row (left, right), one row per bone:
#
#   L0 --- R0   ← bone 0
#   |       |
#   L1 --- R1   ← bone 1
#   |       |
#   ...
#   LN --- RN   ← bone N
#
# Each row of vertices is fully weighted to its bone.
# The row between bone i and bone i+1 is split 50/50 — smooth transition.
# ---------------------------------------------------------------------------

func _build_skinned_mesh(skeleton: Skeleton3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_w := strap_width * 0.5
	# Total rows = one per bone, plus one extra at the very tip
	var rows := bone_count + 1

	for row in range(rows):
		# Which bone owns this row
		var bone_idx := mini(row, bone_count - 1)
		var y := -row * bone_length

		# UV: u=0 left edge, u=1 right edge; v runs 0..1 along full length
		var v_coord := float(row) / float(rows - 1)

		# Left vertex
		st.set_uv(Vector2(0.0, v_coord))
		st.set_bones(PackedInt32Array([bone_idx, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.add_vertex(Vector3(-half_w, y, 0.0))

		# Right vertex
		st.set_uv(Vector2(1.0, v_coord))
		st.set_bones(PackedInt32Array([bone_idx, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.set_normal(Vector3(0.0, 0.0, 1.0))
		st.add_vertex(Vector3(half_w, y, 0.0))

	# Build triangles — two tris per quad between row i and row i+1
	#   L(i)  R(i)
	#   L(i+1) R(i+1)
	# vertex index = row * 2 + (0=left, 1=right)
	for row in range(rows - 1):
		var l0 := row * 2
		var r0 := row * 2 + 1
		var l1 := (row + 1) * 2
		var r1 := (row + 1) * 2 + 1

		# Front face
		st.add_index(l0); st.add_index(r0); st.add_index(l1)
		st.add_index(r0); st.add_index(r1); st.add_index(l1)
		# Back face (so it's visible from both sides)
		st.add_index(l0); st.add_index(l1); st.add_index(r0)
		st.add_index(r0); st.add_index(l1); st.add_index(r1)

	# Material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = strap_color if strap_color != null else Color(0.05, 0.05, 0.05)
	mat.roughness = 0.8
	if strap_texture:
		mat.albedo_texture = strap_texture

	# Commit to ArrayMesh
	var mesh := st.commit()

	# MeshInstance3D with skin
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "LanyardMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat

	# Bind skin — one bind pose per bone
	var skin := Skin.new()
	skin.set_bind_count(bone_count)
	for i in range(bone_count):
		skin.set_bind_bone(i, i)
		# Bind pose = inverse of bone's rest transform in skeleton space
		var rest_pos := Vector3(0.0, -i * bone_length, 0.0)
		skin.set_bind_pose(i, Transform3D(Basis(), -rest_pos))
		skin.set_bind_name(i, _bone_name(i))

	mesh_instance.skin = skin
	mesh_instance.skeleton = NodePath("../LanyardSkeleton")

	add_child(mesh_instance)
	mesh_instance.owner = _get_owner()


# ---------------------------------------------------------------------------
# SpringBoneSimulator3D
# ---------------------------------------------------------------------------

func _build_spring_simulator(skeleton: Skeleton3D) -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "SpringBoneSimulator3D"
	skeleton.add_child(sim)
	sim.owner = _get_owner()

	var plane := SpringBoneCollisionPlane3D.new()
	plane.name = "FloorCollision"
	sim.add_child(plane)
	plane.owner = _get_owner()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _bone_name(i: int) -> String:
	return "Bone_%02d" % i

func _get_owner() -> Node:
	return owner if owner else self
