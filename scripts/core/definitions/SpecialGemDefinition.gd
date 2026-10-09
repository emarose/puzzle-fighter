class_name SpecialGemDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var color_id: String = ""
@export_range(3, 99, 1) var minimum_match_size: int = 3
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(0, 99, 1) var energy_cost: int = 0
@export_range(0.0, 100.0, 0.1) var spawn_weight: float = 1.0
@export var effect_type: String = ""
@export var effect_parameters: Dictionary = {}
@export_group("Effect Animation")
## Horizontal strip; each frame is a square the size of the sheet height.
@export var effect_animation: Texture2D
@export_range(1.0, 60.0, 1.0) var effect_animation_fps: float = 12.0
@export var effect_animation_scale: float = 1.0
## Offset from the center of the targeted actor sprite.
@export var effect_animation_offset: Vector2 = Vector2.ZERO
@export_group("")

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

func get_requirement_text() -> String:
	var parts: PackedStringArray = ["%d+" % minimum_match_size]
	if energy_cost > 0:
		parts.append("%dE" % energy_cost)
	if activation_chance < 1.0:
		parts.append("%d%%" % int(round(activation_chance * 100.0)))
	return " ".join(parts)
