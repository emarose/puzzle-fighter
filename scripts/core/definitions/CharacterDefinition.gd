class_name CharacterDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var max_hp: int = 100
@export var skill_ids: Array[String] = []
@export var attack_modifiers: Dictionary = {}
@export var portrait_path: String = ""
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_max_hp: int = 100) -> void:
    id = p_id
    name = p_name
    max_hp = p_max_hp
