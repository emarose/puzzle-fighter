class_name ColorDefinition
extends Resource

enum CombatRole {
	DAMAGE,
	DEFENSE,
	HEAL,
	ENERGY,
}

@export var id: String = ""
@export var name: String = ""
@export var attack_behavior: String = "standard"
@export var display_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 10.0, 0.05) var attack_modifier: float = 1.0
@export_range(0.0, 10.0, 0.05) var effect_multiplier: float = 1.0
@export var combat_role: CombatRole = CombatRole.DAMAGE
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_attack_behavior: String = "standard", p_display_color: Color = Color.WHITE, p_attack_modifier: float = 1.0, p_combat_role: CombatRole = CombatRole.DAMAGE, p_effect_multiplier: float = 1.0) -> void:
	id = p_id
	name = p_name
	attack_behavior = p_attack_behavior
	display_color = p_display_color
	attack_modifier = p_attack_modifier
	combat_role = p_combat_role
	effect_multiplier = p_effect_multiplier

static func default_palette() -> Dictionary:
	return {
		"red": ColorDefinition.new("red", "Red", "damage", Color(1.0, 0.3, 0.35), 1.35, CombatRole.DAMAGE, 1.0),
		"blue": ColorDefinition.new("blue", "Blue", "defense", Color(0.35, 0.55, 1.0), 0.75, CombatRole.DEFENSE, 0.5),
		"green": ColorDefinition.new("green", "Green", "heal", Color(0.3, 0.9, 0.55), 0.9, CombatRole.HEAL, 0.75),
		"yellow": ColorDefinition.new("yellow", "Yellow", "energy", Color(1.0, 0.8, 0.2), 0.8, CombatRole.ENERGY, 0.4),
	}
