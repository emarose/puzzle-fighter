class_name EnemyDefinition
extends CombatantDefinition

@export var turn_pattern: EnemyTurnPattern
@export var difficulty: float = 1.0
@export_range(0.01, 2.0, 0.01) var fall_step_seconds: float = 0.14

func _init(p_id: String = "", p_name: String = "", p_max_hp: int = 100, _p_attack_pattern: String = "standard") -> void:
	super._init(p_id, p_name, p_max_hp)
