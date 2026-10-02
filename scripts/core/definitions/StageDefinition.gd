class_name StageDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var board_size: Vector2i = Vector2i(6, 10)
@export var available_colors: Array[String] = [
    "red",
    "blue",
    "green",
    "yellow",
]
@export var enemy_id: String = ""
@export var difficulty: float = 1.0
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_board_size: Vector2i = Vector2i(6, 10), p_enemy_id: String = "") -> void:
    id = p_id
    name = p_name
    board_size = p_board_size
    enemy_id = p_enemy_id
