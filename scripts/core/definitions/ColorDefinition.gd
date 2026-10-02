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
@export var attack_modifier: float = 1.0
@export var combat_role: CombatRole = CombatRole.DAMAGE
@export var metadata: Dictionary = {}

func _init(p_id: String = "", p_name: String = "", p_attack_behavior: String = "standard", p_display_color: Color = Color.WHITE, p_attack_modifier: float = 1.0, p_combat_role: CombatRole = CombatRole.DAMAGE) -> void:
    id = p_id
    name = p_name
    attack_behavior = p_attack_behavior
    display_color = p_display_color
    attack_modifier = p_attack_modifier
    combat_role = p_combat_role

static func default_palette() -> Dictionary:
    return {
        "red": ColorDefinition.new("red", "Red", "damage", Color(1.0, 0.3, 0.35), 1.2, CombatRole.DAMAGE),
        "blue": ColorDefinition.new("blue", "Blue", "defense", Color(0.35, 0.55, 1.0), 0.9, CombatRole.DEFENSE),
        "green": ColorDefinition.new("green", "Green", "heal", Color(0.3, 0.9, 0.55), 1.1, CombatRole.HEAL),
        "yellow": ColorDefinition.new("yellow", "Yellow", "energy", Color(1.0, 0.8, 0.2), 1.0, CombatRole.ENERGY),
    }
