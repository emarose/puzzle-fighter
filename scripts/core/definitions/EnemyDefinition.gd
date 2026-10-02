class_name EnemyDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var max_hp: int = 100
@export var attack_pattern: String = "standard"
@export var skill_ids: Array[String] = []
@export var difficulty: float = 1.0
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_max_hp: int = 100, p_attack_pattern: String = "standard") -> void:
    id = p_id
    name = p_name
    max_hp = p_max_hp
    attack_pattern = p_attack_pattern
