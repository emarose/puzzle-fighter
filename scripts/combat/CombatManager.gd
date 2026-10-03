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

func calculate_color_modifier(color_id: String) -> float:
	if not color_palette.has(color_id):
		return 1.0
	return float(color_palette[color_id].attack_modifier)

func apply_damage(actor_id: String, amount: int) -> int:
	if not actors.has(actor_id):
		return 0

	var actor: Dictionary = actors[actor_id]
	var current_hp: int = int(actor.get("current_hp", 0))
	var previous_hp: int = current_hp
	current_hp = max(0, current_hp - amount)
	actor["current_hp"] = current_hp
	actors[actor_id] = actor
	if event_bus != null:
		event_bus.emit("hp_changed", {
			"actor_id": actor_id,
			"previous_hp": previous_hp,
			"current_hp": current_hp,
			"amount": amount,
			"type": "damage",
		})
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
			"amount": amount,
			"type": "heal",
		})
	return current_hp

func create_attack_event(source: String, target: String, color_id: String, base_damage: int, cascade_count: int = 0, combo_multiplier: float = 1.0, special_effects: Array = []) -> AttackEvent:
	var cascade_bonus: int = max(0, cascade_count - 1) * 2
	var color_modifier: float = calculate_color_modifier(color_id)
	var total_damage: int = max(0, int(float(base_damage + cascade_bonus) * color_modifier))
	total_damage = int(float(total_damage) * combo_multiplier)
	return AttackEvent.new(source, target, color_id, total_damage, cascade_bonus, combo_multiplier, special_effects)

func resolve_attack(source_actor_id: String, target_actor_id: String, color_id: String, base_damage: int, cascade_count: int = 0, combo_multiplier: float = 1.0, special_effects: Array = []) -> AttackEvent:
	var event: AttackEvent = create_attack_event(source_actor_id, target_actor_id, color_id, base_damage, cascade_count, combo_multiplier, special_effects)
	apply_damage(target_actor_id, event.amount)
	return event

func is_actor_defeated(actor_id: String) -> bool:
	if not actors.has(actor_id):
		return false
	return int(actors[actor_id].get("current_hp", 0)) <= 0
