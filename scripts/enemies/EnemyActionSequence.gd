class_name EnemyActionSequence
extends RefCounted

const COLOR_PATTERN: Array[String] = ["red", "blue", "green", "yellow", "red", "green", "blue", "yellow"]

func get_actions(turn_index: int, board_columns: int, pattern: EnemyTurnPattern = null) -> Array:
	var safe_turn: int = max(0, turn_index)
	var active_pattern: EnemyTurnPattern = pattern
	if active_pattern == null:
		active_pattern = load("res://resources/enemies/default_turn_pattern.tres")
	var lane_count: int = max(1, board_columns - 1)
	var preferred_column: int = (safe_turn * active_pattern.preferred_column_step) % lane_count
	var is_vertical: bool = (
		active_pattern.vertical_piece_every > 0
		and safe_turn % active_pattern.vertical_piece_every == active_pattern.vertical_piece_every - 1
	)
	var color_sequence: Array[String] = active_pattern.color_sequence
	if color_sequence.is_empty():
		color_sequence = COLOR_PATTERN
	var shape: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
	if is_vertical:
		shape[1] = Vector2i.DOWN
	var start_column: int = int((board_columns - 2) / 2.0)
	return [
		{
			"name": "spawn",
			"color": color_sequence[safe_turn % color_sequence.size()],
			"column": preferred_column,
			"shape": shape,
			"start_column": clampi(start_column, 0, max(0, board_columns - 2)),
		},
		{"name": "move"},
		{"name": "rotate"},
		{"name": "fall"},
		{"name": "lock"},
		{"name": "resolve"},
	]
