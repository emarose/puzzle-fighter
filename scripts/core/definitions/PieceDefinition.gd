class_name PieceDefinition
extends Resource

@export var id: String = ""
@export var color_id: String = ""
@export var type: String = "pair"
@export var visual_name: String = ""
@export var sprite_path: String = ""
@export var effects: Array[String] = []
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_color_id: String = "", p_type: String = "pair", p_visual_name: String = "") -> void:
    id = p_id
    color_id = p_color_id
    type = p_type
    visual_name = p_visual_name
