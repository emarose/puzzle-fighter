class_name SkillEffect
extends RefCounted

var id: String = ""
var type: String = "damage"
var target: String = "enemy"
var amount: int = 0
var metadata: Dictionary = {}

func _init(p_id: String = "", p_type: String = "damage", p_target: String = "enemy", p_amount: int = 0, p_metadata: Dictionary = {}) -> void:
    id = p_id
    type = p_type
    target = p_target
    amount = max(0, p_amount)
    metadata = p_metadata
