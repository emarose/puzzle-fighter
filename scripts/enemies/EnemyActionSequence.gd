class_name EnemyActionSequence
extends RefCounted

const COLOR_PATTERN: Array[String] = ["red", "blue", "green", "yellow", "red", "green", "blue", "yellow"]

func get_actions(turn_index: int, board_columns: int) -> Array:
    var safe_turn: int = max(0, turn_index)
    var lane_count: int = max(1, board_columns - 1)
    var preferred_column: int = (safe_turn * 2) % lane_count
    var is_vertical: bool = safe_turn % 3 == 2
    var shape: Array[Vector2i] = [Vector2i.ZERO, Vector2i.DOWN] if is_vertical else [Vector2i.ZERO, Vector2i.RIGHT]
    return [
        {
            "name": "spawn",
            "color": COLOR_PATTERN[safe_turn % COLOR_PATTERN.size()],
            "column": preferred_column,
            "shape": shape,
            "start_column": clampi((board_columns - 2) / 2, 0, max(0, board_columns - 2)),
        },
        {"name": "move"},
        {"name": "rotate"},
        {"name": "fall"},
        {"name": "lock"},
        {"name": "resolve"},
    ]
