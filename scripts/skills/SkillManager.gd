class_name SkillManager
extends RefCounted

var skill_definitions: Dictionary = {}

func _init() -> void:
    register_default_skills()

func register_default_skills() -> void:
    var burst: SkillDefinition = SkillDefinition.new("burst", "Burst", 1, "damage", "enemy")
    burst.parameters = {"amount": 12, "color": "red"}
    skill_definitions[burst.id] = burst

    var heal: SkillDefinition = SkillDefinition.new("heal", "Heal", 1, "heal", "self")
    heal.parameters = {"amount": 10}
    skill_definitions[heal.id] = heal

    var pulse: SkillDefinition = SkillDefinition.new("pulse", "Pulse", 1, "damage", "enemy")
    pulse.parameters = {"amount": 8, "color": "yellow"}
    skill_definitions[pulse.id] = pulse

func get_skill(skill_id: String) -> SkillDefinition:
    return skill_definitions.get(skill_id, null)

func execute_skill(skill_id: String, combat_manager: CombatManager, source_actor_id: String, target_actor_id: String = "") -> Dictionary:
    if combat_manager == null:
        return {"success": false, "reason": "combat_manager_missing"}

    var definition: SkillDefinition = get_skill(skill_id)
    if definition == null:
        return {"success": false, "reason": "unknown_skill", "skill_id": skill_id}

    var amount: int = int(definition.parameters.get("amount", 0))
    var effect: SkillEffect = SkillEffect.new(definition.id, definition.effect_type, definition.target, amount, definition.parameters)
    var result: Dictionary = {
        "success": true,
        "skill_id": definition.id,
        "effect_type": definition.effect_type,
        "target": definition.target,
        "amount": 0,
        "source": source_actor_id,
        "target_actor": target_actor_id,
    }

    match definition.effect_type:
        "damage":
            if target_actor_id.is_empty():
                result["success"] = false
                result["reason"] = "target_required"
                return result
            combat_manager.apply_damage(target_actor_id, amount)
            result["amount"] = amount
            result["remaining_hp"] = combat_manager.get_actor_hp(target_actor_id)

        "heal":
            if source_actor_id.is_empty():
                result["success"] = false
                result["reason"] = "source_required"
                return result
            combat_manager.heal(source_actor_id, amount)
            result["amount"] = amount
            result["remaining_hp"] = combat_manager.get_actor_hp(source_actor_id)

        _:
            result["success"] = false
            result["reason"] = "unsupported_effect_type"
            result["effect_type"] = definition.effect_type
            return result

    return result
