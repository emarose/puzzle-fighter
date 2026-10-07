class_name CombatTuning
extends Resource

@export_range(0, 99, 1) var max_energy: int = 9
@export_range(0, 10000, 1) var damage_floor: int = 15
@export_range(0, 1000, 1) var cascade_bonus_per_extra_wave: int = 2
@export_range(0.0, 10.0, 0.05) var combo_step_per_extra_wave: float = 0.5
@export var color_definitions: Array = []

func get_color_palette() -> Dictionary:
	var palette: Dictionary = {}
	for resource in color_definitions:
		if resource is ColorDefinition:
			var definition: ColorDefinition = resource as ColorDefinition
			if not definition.id.is_empty():
				palette[definition.id] = definition
	return palette
