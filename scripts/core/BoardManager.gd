extends Node

class_name BoardManager

const DEFAULT_COLUMNS: int = 6
const DEFAULT_ROWS: int = 10

var columns: int = DEFAULT_COLUMNS
var rows: int = DEFAULT_ROWS
var cells: Dictionary = {}
var combat_tuning: CombatTuning = preload("res://resources/combat_tuning.tres")

func _ready() -> void:
	reset_board()

func reset_board(size: Vector2i = Vector2i(DEFAULT_COLUMNS, DEFAULT_ROWS)) -> void:
	columns = size.x
	rows = size.y
	cells.clear()

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
