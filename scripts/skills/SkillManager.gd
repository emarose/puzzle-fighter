class_name SkillManager
extends RefCounted

var skill_definitions: Dictionary = {}
var energy_by_actor: Dictionary = {}
var event_bus: EventBus
var max_energy: int = 9

func _init(catalog: SkillCatalog = null, combat_tuning: CombatTuning = null) -> void:
    event_bus = EventBus.get_instance()
    if event_bus != null and not event_bus.event_emitted.is_connected(_on_event_emitted):
        event_bus.event_emitted.connect(_on_event_emitted)
    configure(catalog, combat_tuning)

func configure(catalog: SkillCatalog = null, combat_tuning: CombatTuning = null) -> void:
    if combat_tuning != null:
        max_energy = max(0, combat_tuning.max_energy)
    if catalog == null:
        catalog = load("res://resources/skills/default_skill_catalog.tres")
    if catalog == null:
        push_error("SkillManager requires a valid SkillCatalog resource.")
        return
    skill_definitions.clear()
    for resource in catalog.skills:
        if resource is SkillDefinition:
            var definition: SkillDefinition = resource as SkillDefinition
            skill_definitions[definition.id] = definition

func register_default_skills() -> void:
    configure()

func get_skill(skill_id: String) -> SkillDefinition:
    return skill_definitions.get(skill_id, null)

func get_energy(actor_id: String) -> int:
    return int(energy_by_actor.get(actor_id, 0))

func add_energy(actor_id: String, amount: int) -> int:
    if actor_id.is_empty() or amount <= 0:
        return get_energy(actor_id)
    var current_energy: int = get_energy(actor_id)
    var next_energy: int = min(max_energy, current_energy + amount)
    energy_by_actor[actor_id] = next_energy
    if event_bus != null:
        event_bus.emit("skill_energy_changed", {"actor_id": actor_id, "energy": next_energy})
    return next_energy

func set_energy(actor_id: String, amount: int) -> int:
    if actor_id.is_empty():
        return 0
    var next_energy: int = clampi(amount, 0, max_energy)
    energy_by_actor[actor_id] = next_energy
    return next_energy

func _on_event_emitted(event_name: String, payload: Dictionary) -> void:
    if event_name == "energy_gain":
        add_energy(str(payload.get("actor_id", "")), int(payload.get("amount", 0)))

func execute_skill(skill_id: String, combat_manager: CombatManager, source_actor_id: String, target_actor_id: String = "") -> Dictionary:
    if combat_manager == null:
        return {"success": false, "reason": "combat_manager_missing"}

    var definition: SkillDefinition = get_skill(skill_id)
    if definition == null:
        return {"success": false, "reason": "unknown_skill", "skill_id": skill_id}
    if not combat_manager.actors.has(source_actor_id):
        return {"success": false, "reason": "source_missing", "source": source_actor_id}
    if get_energy(source_actor_id) < definition.cost:
        return {"success": false, "reason": "insufficient_energy", "required": definition.cost, "available": get_energy(source_actor_id)}

    var effect: SkillEffect = SkillEffect.new(
        definition.id,
        definition.effect_type,
        definition.target,
        int(definition.parameters.get("amount", 0)),
        definition.parameters
    )
    var amount: int = effect.amount
    var resolved_target_id: String = source_actor_id if effect.target == "self" else target_actor_id
    var result: Dictionary = {
        "success": true,
        "skill_id": effect.id,
        "effect_type": effect.type,
        "target": effect.target,
        "amount": 0,
        "source": source_actor_id,
        "target_actor": resolved_target_id,
    }

    match effect.type:
        "damage":
            if resolved_target_id.is_empty():
                result["success"] = false
                result["reason"] = "target_required"
                return result
            if not combat_manager.actors.has(resolved_target_id):
                result["success"] = false
                result["reason"] = "target_missing"
                return result
            var previous_hp: int = combat_manager.get_actor_hp(resolved_target_id)
            combat_manager.apply_damage(resolved_target_id, amount)
            result["amount"] = previous_hp - combat_manager.get_actor_hp(resolved_target_id)
            result["remaining_hp"] = combat_manager.get_actor_hp(resolved_target_id)

        "heal":
            if resolved_target_id.is_empty():
                result["success"] = false
                result["reason"] = "target_required"
                return result
            if not combat_manager.actors.has(resolved_target_id):
                result["success"] = false
                result["reason"] = "target_missing"
                return result
            var previous_hp: int = combat_manager.get_actor_hp(resolved_target_id)
            combat_manager.heal(resolved_target_id, amount)
            result["amount"] = combat_manager.get_actor_hp(resolved_target_id) - previous_hp
            result["remaining_hp"] = combat_manager.get_actor_hp(resolved_target_id)

        _:
            result["success"] = false
            result["reason"] = "unsupported_effect_type"
            result["effect_type"] = effect.type
            return result

    energy_by_actor[source_actor_id] = get_energy(source_actor_id) - definition.cost
    result["energy_remaining"] = get_energy(source_actor_id)
    if event_bus != null:
        event_bus.emit("skill_energy_changed", {"actor_id": source_actor_id, "energy": get_energy(source_actor_id)})
        event_bus.emit("skill_used", {
            "actor_id": source_actor_id,
            "skill_id": definition.id,
            "target_actor": result.target_actor,
            "amount": result.amount,
        })
    return result
