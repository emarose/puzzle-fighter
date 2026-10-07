class_name SpecialGemLoadout
extends Resource

@export_range(0, 8, 1) var max_equipped: int = 2
@export_range(0.0, 1.0, 0.01) var spawn_chance: float = 0.15
@export var selected_gems: Array[SpecialGemDefinition] = []

func get_equipped_gems() -> Array[SpecialGemDefinition]:
	var equipped: Array[SpecialGemDefinition] = []
	var seen_ids: Dictionary = {}
	for definition in selected_gems:
		if equipped.size() >= max_equipped:
			break
		if definition == null or definition.id.is_empty() or seen_ids.has(definition.id):
			continue
		seen_ids[definition.id] = true
		equipped.append(definition)
	return equipped

func get_gem(gem_id: String) -> SpecialGemDefinition:
	for definition in get_equipped_gems():
		if definition.id == gem_id:
			return definition
	return null

func get_gems_for_color(color_id: String) -> Array[SpecialGemDefinition]:
	var matching_gems: Array[SpecialGemDefinition] = []
	for definition in get_equipped_gems():
		if definition.color_id == color_id and definition.spawn_weight > 0.0:
			matching_gems.append(definition)
	return matching_gems
