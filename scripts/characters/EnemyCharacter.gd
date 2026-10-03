class_name EnemyCharacter
extends EnemyDefinition

@export var current_hp: int = 100

func _init(p_id: String = "enemy", p_name: String = "Enemy", p_max_hp: int = 100, p_attack_pattern: String = "standard") -> void:
	super._init(p_id, p_name, p_max_hp, p_attack_pattern)
	current_hp = p_max_hp
