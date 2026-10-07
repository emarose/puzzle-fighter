extends Node

class_name BoardManager

const DEFAULT_COLUMNS: int = 6
const DEFAULT_ROWS: int = 10

var columns: int = DEFAULT_COLUMNS
var rows: int = DEFAULT_ROWS
var cells: Dictionary = {}
var prepared_groups: Array = []
var prepared_group_next_id: int = 0
var combat_tuning: CombatTuning = preload("res://resources/combat_tuning.tres")
var event_bus: EventBus

func _ready() -> void:
	event_bus = EventBus.get_instance()
	reset_board()

func reset_board(size: Vector2i = Vector2i(DEFAULT_COLUMNS, DEFAULT_ROWS)) -> void:
	columns = size.x
	rows = size.y
	cells.clear()
	prepared_groups.clear()
	prepared_group_next_id = 0

	for y in range(rows):
		for x in range(columns):
			var cell_position := Vector2i(x, y)
			cells[cell_key(cell_position)] = BoardCell.new(cell_position, "", "")

func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func is_within_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows

func get_cell(cell: Vector2i) -> BoardCell:
	if not is_within_bounds(cell):
		return BoardCell.new(cell, "", "")

	var key := cell_key(cell)
	if not cells.has(key):
		cells[key] = BoardCell.new(cell, "", "")

	return cells[key]

func set_cell(cell: Vector2i, color_id: String, piece_id: String = "") -> bool:
	if not is_within_bounds(cell):
		return false

	var target_cell: BoardCell = get_cell(cell)
	target_cell.color_id = color_id
	target_cell.piece_id = piece_id
	target_cell.is_empty = color_id.is_empty()
	cells[cell_key(cell)] = target_cell
	return true

func clear_cell(cell: Vector2i) -> void:
	set_cell(cell, "", "")

func is_cell_empty(cell: Vector2i) -> bool:
	if not is_within_bounds(cell):
		return false

	return get_cell(cell).is_empty

func can_place_block_positions(block_positions: Array, origin: Vector2i = Vector2i.ZERO) -> bool:
	for offset in block_positions:
		if typeof(offset) != TYPE_VECTOR2I:
			return false

		var target := Vector2i(offset.x + origin.x, offset.y + origin.y)
		if not is_within_bounds(target):
			return false

		if not is_cell_empty(target):
			return false

	return true

func can_move_piece_to(piece_positions: Array, origin: Vector2i, destination: Vector2i) -> bool:
	var relative_positions: Array = []
	for offset in piece_positions:
		relative_positions.append(Vector2i(offset.x + destination.x - origin.x, offset.y + destination.y - origin.y))

	return can_place_block_positions(relative_positions, Vector2i.ZERO)

func can_rotate_piece(piece_positions: Array, origin: Vector2i, rotation_steps: int = 1) -> bool:
	var rotated_positions: Array = []
	var steps: int = rotation_steps % 4

	for offset in piece_positions:
		var next_offset: Vector2i = Vector2i(offset.x, offset.y)
		for _i in range(steps):
			next_offset = Vector2i(-next_offset.y, next_offset.x)
		rotated_positions.append(next_offset)

	for position in rotated_positions:
		var target := Vector2i(position.x + origin.x, position.y + origin.y)
		if not is_within_bounds(target):
			return false

	return true

func lock_piece(piece_positions: Array, origin: Vector2i, color_id: String, piece_id: String = "") -> Array:
	var locked_positions: Array = []

	for offset in piece_positions:
		var world_position := Vector2i(offset.x + origin.x, offset.y + origin.y)
		if not is_within_bounds(world_position):
			continue

		set_cell(world_position, color_id, piece_id)
		locked_positions.append(world_position)

	return locked_positions

func lock_piece_blocks(blocks: Array, origin: Vector2i, piece_id: String = "") -> Array:
	if blocks.size() != 2:
		return []
	var positions: Array = []
	var colors: Array[String] = []
	for block in blocks:
		if typeof(block) != TYPE_DICTIONARY:
			return []
		var local_position: Variant = block.get("local_position", Vector2i.ZERO)
		var color_id: String = str(block.get("color_id", ""))
		if typeof(local_position) != TYPE_VECTOR2I or color_id.is_empty():
			return []
		positions.append(origin + local_position)
		colors.append(color_id)
	if not can_place_block_positions(positions):
		return []
	for index in range(positions.size()):
		set_cell(positions[index], colors[index], piece_id)
	return positions

func apply_gravity() -> void:
	for x in range(columns):
		var column_cells: Array = []
		for y in range(rows - 1, -1, -1):
			var current_cell := Vector2i(x, y)
			if not is_cell_empty(current_cell):
				column_cells.append(current_cell)

		for y in range(rows - 1, -1, -1):
			if column_cells.is_empty():
				set_cell(Vector2i(x, y), "", "")
				continue

			var source_cell: Vector2i = column_cells.pop_front()
			var source_data: BoardCell = get_cell(source_cell)
			var target_cell: Vector2i = Vector2i(x, y)
			if source_cell != target_cell:
				set_cell(target_cell, source_data.color_id, source_data.piece_id)
				set_cell(source_cell, "", "")
	prepared_groups = refresh_prepared_groups(prepared_groups)

func detect_matches() -> Array:
	var matches: Array = []
	var checked: Dictionary = {}

	for y in range(rows):
		for x in range(columns):
			var current_cell: BoardCell = get_cell(Vector2i(x, y))
			if current_cell.is_empty:
				continue

			var key := cell_key(Vector2i(x, y))
			if checked.has(key):
				continue

			var group: Array = []
			var queue: Array = [Vector2i(x, y)]
			var color_id: String = current_cell.color_id

			while not queue.is_empty():
				var cell_position: Vector2i = queue.pop_front()
				var cell_key_value := cell_key(cell_position)
				if checked.has(cell_key_value):
					continue

				checked[cell_key_value] = true
				group.append(cell_position)

				for neighbor in [
					Vector2i(1, 0),
					Vector2i(-1, 0),
					Vector2i(0, 1),
					Vector2i(0, -1),
				]:
					var neighbor_position = cell_position + neighbor
					if not is_within_bounds(neighbor_position):
						continue

					var neighbor_cell: BoardCell = get_cell(neighbor_position)
					if neighbor_cell.is_empty:
						continue
					if neighbor_cell.color_id != color_id:
						continue

					if not checked.has(cell_key(neighbor_position)):
						queue.append(neighbor_position)

			if group.size() >= 3:
				matches.append(group)

	return matches

func resolve_cascade() -> int:
	var result: CascadeManager.CascadeResult = resolve_cascade_result()
	return result.cascade_count

func resolve_cascade_result(actor_id: String = "") -> CascadeManager.CascadeResult:
	var cascade_manager := CascadeManager.new()
	var result: CascadeManager.CascadeResult = cascade_manager.resolve(self, MatchManager.new(), actor_id, combat_tuning)
	return result

func resolve_prepared_group(group: MatchManager.PreparedGroup, actor_id: String = "") -> Dictionary:
	if group == null or group.cells.is_empty():
		return {"resolved": false, "blocks_removed": 0, "color_id": "", "group": null}

	var resolved_index: int = prepared_groups.find(group)
	if resolved_index >= 0:
		prepared_groups.remove_at(resolved_index)

	group.is_resolving = true
	var color_id: String = group.color_id
	var removed_count: int = 0
	var group_cells: Array = group.cells.duplicate()

	for cell_position in group_cells:
		if typeof(cell_position) != TYPE_VECTOR2I:
			continue
		if not is_within_bounds(cell_position):
			continue
		if is_cell_empty(cell_position):
			continue
		clear_cell(cell_position)
		removed_count += 1
	if event_bus != null:
		event_bus.emit("prepared_group_resolved", {"actor_id": actor_id, "color_id": color_id, "blocks_removed": removed_count})
	apply_gravity()
	prepared_groups = refresh_prepared_groups(prepared_groups)
	prepared_groups = detect_prepared_groups_for_board()
	group.is_prepared = false
	group.is_resolving = false
	if event_bus != null:
		event_bus.emit("prepared_groups_updated", {
			"actor_id": actor_id,
			"count": prepared_groups.size(),
		})
	return {"resolved": true, "blocks_removed": removed_count, "color_id": color_id, "group": group}

func find_prepared_group_for_cell(groups: Array, cell: Vector2i) -> MatchManager.PreparedGroup:
	if groups.is_empty():
		return null
	for group in groups:
		if group == null:
			continue
		if group is MatchManager.PreparedGroup and group.contains_cell(cell):
			return group
	return null

func refresh_prepared_groups(groups: Array) -> Array:
	var valid_groups: Array = []
	for group in groups:
		if group == null:
			continue
		if group.cells.is_empty():
			continue
		var valid_cells: Array = []
		for cell_position in group.cells:
			if typeof(cell_position) != TYPE_VECTOR2I:
				continue
			if not is_within_bounds(cell_position):
				continue
			if is_cell_empty(cell_position):
				continue
			valid_cells.append(cell_position)
		if valid_cells.size() >= 3:
			group.cells = valid_cells
			group.size = valid_cells.size()
			group.is_prepared = true
			group.is_resolving = false
			valid_groups.append(group)
	return valid_groups

func resolve_cascade_animated_result(
	actor_id: String = "",
	before_destroy: Callable = Callable()
) -> CascadeManager.CascadeResult:
	var cascade_manager := CascadeManager.new()
	var result: CascadeManager.CascadeResult = await cascade_manager.resolve_animated(
		self,
		MatchManager.new(),
		actor_id,
		combat_tuning,
		before_destroy
	)
	prepared_groups = detect_prepared_groups_for_board()
	if event_bus != null:
		event_bus.emit("prepared_groups_updated", {
			"actor_id": actor_id,
			"count": prepared_groups.size(),
		})
	return result

func detect_prepared_groups_for_board() -> Array:
	var tracking: Dictionary = {"next_id": prepared_group_next_id}
	var detected_groups: Array = MatchManager.new().detect_prepared_groups(self, tracking)
	prepared_group_next_id = int(tracking.get("next_id", prepared_group_next_id))
	var previous_groups: Array = prepared_groups
	var synced: Array = []
	for group in detected_groups:
		for old_group in previous_groups:
			if old_group == null or old_group.color_id != group.color_id:
				continue
			var overlaps: bool = false
			for cell_position in group.cells:
				if old_group.contains_cell(cell_position):
					overlaps = true
					break
			if overlaps:
				group.id = old_group.id
				break
		synced.append(group)
	prepared_groups = synced
	return prepared_groups

func _highest_group_id(groups: Array) -> int:
	var highest: int = -1
	for group in groups:
		if group == null:
			continue
		if group.id > highest:
			highest = group.id
	return highest
