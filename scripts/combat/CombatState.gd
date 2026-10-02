class_name CombatState
extends Resource

@export var actor_id: String = ""
@export var max_hp: int = 100
@export var current_hp: int = 100

func _init(p_actor_id: String = "actor", p_max_hp: int = 100, p_current_hp: int = -1) -> void:
    actor_id = p_actor_id
    max_hp = max(1, p_max_hp)
    current_hp = max_hp if p_current_hp < 0 else max(0, p_current_hp)

func reset() -> void:
    current_hp = max_hp

func take_damage(amount: int) -> int:
    var value: int = max(0, amount)
    current_hp = max(0, current_hp - value)
    return current_hp

func heal(amount: int) -> int:
    var value: int = max(0, amount)
    current_hp = min(max_hp, current_hp + value)
    return current_hp

func apply_effect(effect_amount: int) -> int:
    if effect_amount >= 0:
        return heal(effect_amount)
    return take_damage(abs(effect_amount))

func is_defeated() -> bool:
    return current_hp <= 0
