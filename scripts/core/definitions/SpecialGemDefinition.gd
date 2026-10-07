class_name SpecialGemDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var color_id: String = ""
@export_range(3, 99, 1) var minimum_match_size: int = 3
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(0, 99, 1) var energy_cost: int = 0
@export_range(0.0, 100.0, 0.1) var spawn_weight: float = 1.0
@export var effect_type: String = ""
@export var effect_parameters: Dictionary = {}
@export var remove_when_inactive: bool = false

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_color_id: String = "",
	p_effect_type: String = ""
) -> void:
	id = p_id
	display_name = p_display_name
	color_id = p_color_id
	effect_type = p_effect_type
