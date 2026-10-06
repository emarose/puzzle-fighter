class_name PlayerCharacter
extends CharacterDefinition

@export var current_hp: int = 100
@export var attack_multiplier: float = 1.0

func _init(p_id: String = "player", p_name: String = "Player", p_max_hp: int = 100) -> void:
	super._init(p_id, p_name, p_max_hp)
	current_hp = p_max_hp
