class_name CombatTuning
extends Resource

@export_range(0, 99, 1) var max_energy: int = 9
@export_range(0, 10000, 1) var damage_floor: int = 5
@export_range(0, 1000, 1) var cascade_bonus_per_extra_wave: int = 5
@export_range(0.0, 10.0, 0.05) var combo_step_per_extra_wave: float = 0.5
## Per-role multipliers applied to the matched block count (on top of each color's effect_multiplier).
@export_range(0.0, 100.0, 0.05) var damage_per_block: float = 1.0
@export_range(0.0, 100.0, 0.05) var defense_per_block: float = 1.0
@export_range(0.0, 100.0, 0.05) var heal_per_block: float = 1.0
@export_range(0.0, 100.0, 0.05) var energy_per_block: float = 1.0
@export var color_definitions: Array = []

func get_role_per_block(role: int) -> float:
	match role:
		ColorDefinition.CombatRole.DAMAGE:
			return damage_per_block
		ColorDefinition.CombatRole.DEFENSE:
			return defense_per_block
		ColorDefinition.CombatRole.HEAL:
			return heal_per_block
		ColorDefinition.CombatRole.ENERGY:
			return energy_per_block
	return 1.0

func get_color_palette() -> Dictionary:
	var palette: Dictionary = {}
	for resource in color_definitions:
		if resource is ColorDefinition:
			var definition: ColorDefinition = resource as ColorDefinition
			if not definition.id.is_empty():
				palette[definition.id] = definition
	return palette
