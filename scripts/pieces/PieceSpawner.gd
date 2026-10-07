class_name PieceSpawner
extends RefCounted

var next_piece_id: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func create_piece(
	color_id: String,
	logical_position: Vector2i = Vector2i.ZERO,
	shape: Array = [Vector2i(0, 0), Vector2i(1, 0)],
	special_gem_loadout: SpecialGemLoadout = null
) -> Piece:
	return create_piece_with_colors([color_id, color_id], logical_position, shape, special_gem_loadout)

func create_random_piece(
	available_colors: Array,
	logical_position: Vector2i = Vector2i.ZERO,
	shape: Array = [Vector2i(0, 0), Vector2i(1, 0)],
	special_gem_loadout: SpecialGemLoadout = null
) -> Piece:
	var valid_colors: Array[String] = []
	for color_id in available_colors:
		if typeof(color_id) == TYPE_STRING and not color_id.is_empty():
			valid_colors.append(color_id)
	if valid_colors.is_empty():
		push_error("PieceSpawner cannot create a random piece without any available colors.")
		return null
	var color_ids: Array[String] = [
		valid_colors[rng.randi_range(0, valid_colors.size() - 1)],
		valid_colors[rng.randi_range(0, valid_colors.size() - 1)],
	]
	return create_piece_with_colors(color_ids, logical_position, shape, special_gem_loadout)

func create_piece_with_colors(
	color_ids: Array,
	logical_position: Vector2i = Vector2i.ZERO,
	shape: Array = [Vector2i.ZERO, Vector2i.RIGHT],
	special_gem_loadout: SpecialGemLoadout = null
) -> Piece:
	if shape.size() != 2 or color_ids.size() != shape.size():
		push_error("PieceSpawner requires exactly two block positions and exactly two block colors.")
		return null
	var blocks: Array = []
	for index in range(shape.size()):
		var offset: Vector2i = shape[index]
		if typeof(color_ids[index]) != TYPE_STRING or str(color_ids[index]).is_empty():
			push_error("PieceSpawner requires a non-empty color ID for each block.")
			return null
		blocks.append({
			"color_id": color_ids[index],
			"type": "pair",
			"owner_piece": "",
			"local_position": offset,
			"state": "active",
			"special_gem_id": _roll_special_gem(str(color_ids[index]), special_gem_loadout),
		})

	var piece := Piece.new("piece_%d" % next_piece_id, str(color_ids[0]), logical_position, blocks)
	piece.container_piece = "pair"
	next_piece_id += 1
	return piece

func _roll_special_gem(color_id: String, loadout: SpecialGemLoadout) -> String:
	if loadout == null or loadout.spawn_chance <= 0.0 or rng.randf() >= loadout.spawn_chance:
		return ""

	var eligible_gems: Array[SpecialGemDefinition] = loadout.get_gems_for_color(color_id)
	var total_weight: float = 0.0
	for definition in eligible_gems:
		total_weight += definition.spawn_weight
	if total_weight <= 0.0:
		return ""

	var roll: float = rng.randf() * total_weight
	for definition in eligible_gems:
		roll -= definition.spawn_weight
		if roll < 0.0:
			return definition.id
	return eligible_gems.back().id
