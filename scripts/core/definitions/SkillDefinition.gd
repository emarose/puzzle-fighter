class_name SkillDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export_range(0, 99, 1) var cost: int = 0
@export var effect_type: String = "damage"
@export var target: String = "enemy"
@export var parameters: Dictionary = {}
@export var description: String = ""
@export var icon: Texture2D

func _init(p_id: String = "", p_name: String = "", p_cost: int = 0, p_effect_type: String = "damage", p_target: String = "enemy") -> void:
	id = p_id
	name = p_name
	cost = p_cost
	effect_type = p_effect_type
	target = p_target
