class_name SpecialGemDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var short_label: String = ""
@export var color_id: String = ""
@export_range(3, 99, 1) var minimum_match_size: int = 3
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(0, 99, 1) var energy_cost: int = 0
@export_range(0.0, 100.0, 0.1) var spawn_weight: float = 1.0
@export var effect_type: String = ""
@export var effect_parameters: Dictionary = {}

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

func get_short_label() -> String:
	if not short_label.is_empty():
		return short_label.substr(0, 2).to_upper()
	var source: String = display_name if not display_name.is_empty() else id
	return source.substr(0, 1).to_upper()

func get_requirement_text() -> String:
	var parts: PackedStringArray = ["%d+" % minimum_match_size]
	if energy_cost > 0:
		parts.append("%dE" % energy_cost)
	if activation_chance < 1.0:
		parts.append("%d%%" % int(round(activation_chance * 100.0)))
	return " ".join(parts)
