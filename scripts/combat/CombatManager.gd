class_name CombatManager
extends RefCounted

class AttackEvent:
	extends RefCounted

	var source: String = ""
	var target: String = ""
	var color: String = ""
	var amount: int = 0
	var cascade_bonus: int = 0
	var combo_multiplier: float = 1.0
	var special_effects: Array = []

	func _init(p_source: String = "", p_target: String = "", p_color: String = "", p_amount: int = 0, p_cascade_bonus: int = 0, p_combo_multiplier: float = 1.0, p_special_effects: Array = []) -> void:
		source = p_source
		target = p_target
		color = p_color
		amount = p_amount
		cascade_bonus = p_cascade_bonus
		combo_multiplier = p_combo_multiplier
		special_effects = p_special_effects

var actors: Dictionary = {}
var actor_attack_modifiers: Dictionary = {}
var actor_guard: Dictionary = {}
var color_palette: Dictionary = ColorDefinition.default_palette()
var event_bus: EventBus

func _init() -> void:
	event_bus = EventBus.get_instance()

func register_actor(actor_id: String, max_hp: int, current_hp: int = -1) -> void:
	var resolved_hp: int = max_hp if current_hp < 0 else current_hp
	actors[actor_id] = {
		"max_hp": max_hp,
		"current_hp": resolved_hp,
	}

func get_actor_hp(actor_id: String) -> int:
	if not actors.has(actor_id):
		return 0
	return int(actors[actor_id].get("current_hp", 0))

func set_actor_attack_modifiers(actor_id: String, modifiers: Dictionary) -> void:
	actor_attack_modifiers[actor_id] = modifiers.duplicate(true)

func calculate_actor_modifier(actor_id: String, color_id: String) -> float:
	var modifiers: Dictionary = actor_attack_modifiers.get(actor_id, {})
	return float(modifiers.get(color_id, 1.0))

func get_actor_guard(actor_id: String) -> int:
	return int(actor_guard.get(actor_id, 0))

func grant_guard(actor_id: String, amount: int) -> int:
	if not actors.has(actor_id) or amount <= 0:
		return get_actor_guard(actor_id)
	var guard_total: int = get_actor_guard(actor_id) + amount
	actor_guard[actor_id] = guard_total
	if event_bus != null:
		event_bus.emit("guard_applied", {"actor_id": actor_id, "amount": amount, "total_guard": guard_total})
	return guard_total

func get_color_definition(color_id: String) -> ColorDefinition:
	if not color_palette.has(color_id):
		return null
	return color_palette[color_id]

func calculate_color_modifier(color_id: String) -> float:
	var color_definition: ColorDefinition = get_color_definition(color_id)
	if color_definition == null:
		return 1.0
	return float(color_definition.attack_modifier)

func apply_damage(actor_id: String, amount: int) -> int:
	if not actors.has(actor_id):
		return 0

	var actor: Dictionary = actors[actor_id]
	var current_hp: int = int(actor.get("current_hp", 0))
	var previous_hp: int = current_hp
	var incoming_amount: int = max(0, amount)
	var absorbed_amount: int = min(get_actor_guard(actor_id), incoming_amount)
	actor_guard[actor_id] = get_actor_guard(actor_id) - absorbed_amount
	current_hp = max(0, current_hp - (incoming_amount - absorbed_amount))
	actor["current_hp"] = current_hp
	actors[actor_id] = actor
	var damage_received: int = previous_hp - current_hp
	if event_bus != null:
		if absorbed_amount > 0:
			event_bus.emit("guard_absorbed", {"actor_id": actor_id, "amount": absorbed_amount, "remaining_guard": get_actor_guard(actor_id)})
		if damage_received <= 0:
			return current_hp
		var payload: Dictionary = {
			"actor_id": actor_id,
			"previous_hp": previous_hp,
			"current_hp": current_hp,
			"amount": damage_received,
			"incoming_amount": incoming_amount,
			"absorbed_amount": absorbed_amount,
			"type": "damage",
		}
		event_bus.emit("damage_received", payload)
		event_bus.emit("hp_changed", payload)
	return current_hp

func heal(actor_id: String, amount: int) -> int:
	if not actors.has(actor_id):
		return 0

	var actor: Dictionary = actors[actor_id]
	var max_hp: int = int(actor.get("max_hp", 0))
	var current_hp: int = int(actor.get("current_hp", 0))
	var previous_hp: int = current_hp
	current_hp = min(max_hp, current_hp + amount)
	actor["current_hp"] = current_hp
	actors[actor_id] = actor
	if event_bus != null:
		event_bus.emit("hp_changed", {
			"actor_id": actor_id,
			"previous_hp": previous_hp,
			"current_hp": current_hp,
			"amount": current_hp - previous_hp,
			"type": "heal",
		})
	return current_hp

func create_attack_event(source: String, target: String, color_id: String, base_damage: int, cascade_count: int = 0, combo_multiplier: float = 1.0, special_effects: Array = []) -> AttackEvent:
	var cascade_bonus: int = max(0, cascade_count - 1) * 2
	var color_definition: ColorDefinition = get_color_definition(color_id)
	var color_modifier: float = calculate_color_modifier(color_id)
	var character_modifier: float = calculate_actor_modifier(source, color_id)
	var combined_modifier: float = color_modifier * character_modifier * combo_multiplier
	var effect_list: Array = []
	if special_effects != null:
		effect_list = special_effects.duplicate()

	var total_amount: int = 0
	if color_definition == null:
		total_amount = max(0, int(float(base_damage + cascade_bonus) * combined_modifier))
		return AttackEvent.new(source, target, color_id, total_amount, cascade_bonus, combo_multiplier, effect_list)

	match color_definition.combat_role:
		ColorDefinition.CombatRole.DAMAGE:
			total_amount = max(0, int(float(base_damage + cascade_bonus) * combined_modifier))
			return AttackEvent.new(source, target, color_id, total_amount, cascade_bonus, combo_multiplier, effect_list)
		ColorDefinition.CombatRole.DEFENSE:
			total_amount = max(0, int(float(base_damage * 0.5 + cascade_bonus) * combined_modifier))
			effect_list.append("guard")
			return AttackEvent.new(source, source, color_id, total_amount, cascade_bonus, combo_multiplier, effect_list)
		ColorDefinition.CombatRole.HEAL:
			total_amount = max(0, int(float(base_damage * 0.75 + cascade_bonus) * combined_modifier))
			effect_list.append("heal")
			return AttackEvent.new(source, source, color_id, total_amount, cascade_bonus, combo_multiplier, effect_list)
		ColorDefinition.CombatRole.ENERGY:
			total_amount = max(1, int(float(base_damage * 0.4 + cascade_bonus) * combined_modifier)) if base_damage > 0 else 0
			effect_list.append("energy")
			return AttackEvent.new(source, source, color_id, total_amount, cascade_bonus, combo_multiplier, effect_list)
		_:
			total_amount = max(0, int(float(base_damage + cascade_bonus) * combined_modifier))
			return AttackEvent.new(source, target, color_id, total_amount, cascade_bonus, combo_multiplier, effect_list)

func resolve_attack(source_actor_id: String, target_actor_id: String, color_id: String, base_damage: int, cascade_count: int = 0, combo_multiplier: float = 1.0, special_effects: Array = []) -> AttackEvent:
	var event: AttackEvent = create_attack_event(source_actor_id, target_actor_id, color_id, base_damage, cascade_count, combo_multiplier, special_effects)
	apply_attack_event(event)
	return event

func apply_attack_event(event: AttackEvent) -> void:
	if event == null:
		return

	var role: ColorDefinition.CombatRole = ColorDefinition.CombatRole.DAMAGE
	var color_definition: ColorDefinition = get_color_definition(event.color)
	if color_definition != null:
		role = color_definition.combat_role

	if event_bus != null:
		event_bus.emit("attack_created", {
			"source": event.source,
			"target": event.target,
			"color": event.color,
			"amount": event.amount,
			"cascade_bonus": event.cascade_bonus,
			"combo_multiplier": event.combo_multiplier,
		})

	match role:
		ColorDefinition.CombatRole.DAMAGE:
			apply_damage(event.target, event.amount)
		ColorDefinition.CombatRole.DEFENSE:
			grant_guard(event.source, event.amount)
		ColorDefinition.CombatRole.HEAL:
			heal(event.source, event.amount)
		ColorDefinition.CombatRole.ENERGY:
			if event_bus != null:
				event_bus.emit("energy_gain", {
					"actor_id": event.source,
					"amount": event.amount,
					"color": event.color,
				})
		_:
			apply_damage(event.target, event.amount)

func is_actor_defeated(actor_id: String) -> bool:
	if not actors.has(actor_id):
		return false
	return int(actors[actor_id].get("current_hp", 0)) <= 0
