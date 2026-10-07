class_name MatchManager
extends RefCounted

class PreparedGroup:
	extends RefCounted

	var id: int = -1
	var color_id: String = ""
	var cells: Array = []
	var size: int = 0
	var is_prepared: bool = true
	var is_resolving: bool = false
	var special_gems: Array = []

	func _init(
		p_id: int = -1,
		p_color_id: String = "",
		p_cells: Array = [],
		p_is_prepared: bool = true,
		p_special_gems: Array = []
	) -> void:
		id = p_id
		color_id = p_color_id
		cells = p_cells
		size = cells.size()
		is_prepared = p_is_prepared
		is_resolving = false
		special_gems = p_special_gems

	func contains_cell(cell: Vector2i) -> bool:
		for candidate in cells:
			if typeof(candidate) == TYPE_VECTOR2I and candidate == cell:
				return true
		return false

class MatchResult:
	extends RefCounted

	var groups: Array = []
	var match_count: int = 0
	var total_blocks_destroyed: int = 0
	var affected_colors: Array = []

	func _init(p_groups: Array = [], p_match_count: int = 0, p_total_blocks_destroyed: int = 0, p_affected_colors: Array = []) -> void:
		groups = p_groups
		match_count = p_match_count
		total_blocks_destroyed = p_total_blocks_destroyed
		affected_colors = p_affected_colors

func detect_matches(board: BoardManager) -> MatchResult:
	if board == null:
		return MatchResult.new([], 0, 0, [])

	var visited: Dictionary = {}
	var groups: Array = []
	var directions: Array = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]

	for y in range(board.rows):
		for x in range(board.columns):
			var position := Vector2i(x, y)
			if board.is_cell_empty(position):
				continue

			var key := board.cell_key(position)
			if visited.has(key):
				continue

			var group: Array = _flood_fill(board, position, visited, directions)
			if group.size() >= 3:
				groups.append(group)

	var unique_groups: Array = _deduplicate_groups(groups)
	var total_blocks_destroyed: int = 0
	var affected_colors: Dictionary = {}

	for group in unique_groups:
		total_blocks_destroyed += group.size()
		var first_cell: BoardCell = board.get_cell(group[0])
		if not first_cell.is_empty:
			affected_colors[first_cell.color_id] = true

	return MatchResult.new(unique_groups, unique_groups.size(), total_blocks_destroyed, affected_colors.keys())

func detect_prepared_groups(board: BoardManager, active_group_map: Dictionary = {}) -> Array:
	if board == null:
		return []

	var result: Array = []
	var match_result: MatchResult = detect_matches(board)
	if match_result.match_count <= 0:
		return result

	var next_id: int = 0
	if active_group_map.has("next_id"):
		next_id = int(active_group_map.get("next_id", 0))

	for group in match_result.groups:
		if group.is_empty():
			continue
		var color_id: String = board.get_cell(group[0]).color_id
		var special_gems: Array = []
		for cell_position in group:
			var special_gem_id: String = board.get_cell(cell_position).special_gem_id
			if not special_gem_id.is_empty():
				special_gems.append({
					"special_gem_id": special_gem_id,
					"cell_position": cell_position,
				})
		var prepared_group: PreparedGroup = PreparedGroup.new(
			next_id,
			color_id,
			group.duplicate(),
			true,
			special_gems
		)
		next_id += 1
		result.append(prepared_group)

	if active_group_map.has("next_id"):
		active_group_map["next_id"] = next_id
	return result

func find_group_for_cell(groups: Array, cell: Vector2i) -> PreparedGroup:
	for group in groups:
		if group == null:
			continue
		if group is PreparedGroup and group.contains_cell(cell):
			return group
	return null

func _flood_fill(board: BoardManager, start_position: Vector2i, visited: Dictionary, directions: Array) -> Array:
	var group: Array = []
	var queue: Array = [start_position]
	var anchor_color: String = board.get_cell(start_position).color_id

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var key := board.cell_key(current)
		if visited.has(key):
			continue

		visited[key] = true
		group.append(current)

		for direction in directions:
			var next_position = current + direction
			if not board.is_within_bounds(next_position):
				continue

			if board.is_cell_empty(next_position):
				continue

			var neighbor: BoardCell = board.get_cell(next_position)
			if neighbor.color_id != anchor_color:
				continue

			var neighbor_key := board.cell_key(next_position)
			if not visited.has(neighbor_key):
				queue.append(next_position)

	return group

func _deduplicate_groups(groups: Array) -> Array:
	var unique_groups: Array = []
	var seen: Dictionary = {}

	for group in groups:
		var normalized: Array = []
		for cell in group:
			normalized.append(cell)
		normalized.sort_custom(func(a, b):
			if a.y != b.y:
				return a.y < b.y
			return a.x < b.x
		)

		var signature: String = ""
		for cell in normalized:
			signature += "%d,%d;" % [cell.x, cell.y]

		if seen.has(signature):
			continue

		seen[signature] = true
		unique_groups.append(normalized)

	return unique_groups
