class_name EnemyTurnPattern
extends Resource

@export var color_sequence: Array[String] = ["red", "blue", "green", "yellow"]
@export_range(0, 10, 1) var preferred_column_step: int = 2
@export_range(0, 100, 1) var vertical_piece_every: int = 3
@export_range(-1000, 1000, 1) var match_priority: int = 100
@export_range(-1000, 1000, 1) var color_preference: int = 10
@export_range(-1000, 1000, 1) var column_preference: int = 5
@export_range(-1000, 1000, 1) var shape_preference: int = 2
@export_range(0, 100, 1) var skill_use_every_turns: int = 0
