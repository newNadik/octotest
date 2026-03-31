class_name FishSchoolUtils
extends RefCounted


static func random_range(rng: RandomNumberGenerator, a: float, b: float) -> float:
	return rng.randf_range(minf(a, b), maxf(a, b))


static func dominant_cardinal(v: Vector3) -> Vector3:
	if absf(v.x) >= absf(v.z):
		return Vector3.RIGHT if v.x >= 0.0 else Vector3.LEFT
	return Vector3.BACK if v.z >= 0.0 else Vector3.FORWARD


static func pick_school_flow(
	rng: RandomNumberGenerator,
	direction_mode: int,
	flow_direction: Vector3,
	randomize_direction: bool,
	allow_reverse_direction: bool
) -> Vector3:
	var base := flow_direction
	base.y = 0.0
	if base.is_zero_approx():
		base = Vector3.FORWARD
	base = base.normalized()

	if direction_mode == 2:
		return base

	if direction_mode == 1:
		var options: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK]
		if allow_reverse_direction:
			options.append(Vector3.LEFT)
			options.append(Vector3.FORWARD)
		if randomize_direction:
			return options[rng.randi_range(0, options.size() - 1)]
		var chosen := dominant_cardinal(base)
		if not allow_reverse_direction and (chosen == Vector3.LEFT or chosen == Vector3.FORWARD):
			return Vector3.RIGHT if absf(base.x) >= absf(base.z) else Vector3.BACK
		return chosen

	var two_way := dominant_cardinal(base)
	if not allow_reverse_direction and (two_way == Vector3.LEFT or two_way == Vector3.FORWARD):
		two_way = Vector3.RIGHT if absf(base.x) >= absf(base.z) else Vector3.BACK
	if randomize_direction and allow_reverse_direction and rng.randf() < 0.5:
		two_way = -two_way
	return two_way


static func apply_direction_variation(
	rng: RandomNumberGenerator,
	base_dir: Vector3,
	direction_variation_degrees: float
) -> Vector3:
	var dir := base_dir.normalized()
	if dir.is_zero_approx():
		return Vector3.FORWARD
	var variation := absf(direction_variation_degrees)
	if variation <= 0.0:
		return dir
	var yaw := deg_to_rad(rng.randf_range(-variation, variation))
	var varied := dir.rotated(Vector3.UP, yaw).normalized()
	return dir if varied.is_zero_approx() else varied


static func pick_school_species(
	rng: RandomNumberGenerator,
	pool: Array[PackedScene],
	min_species: int,
	max_species: int
) -> Array[PackedScene]:
	var picked: Array[PackedScene] = []
	if pool.is_empty():
		return picked

	var wanted := rng.randi_range(maxi(min_species, 1), maxi(max_species, min_species))
	wanted = mini(wanted, pool.size())
	var indices: Array[int] = []
	for i in pool.size():
		indices.append(i)
	for _n in wanted:
		var idx := rng.randi_range(0, indices.size() - 1)
		picked.append(pool[indices[idx]])
		indices.remove_at(idx)
	return picked
