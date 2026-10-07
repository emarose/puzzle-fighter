class_name SpecialGemManager
extends RefCounted

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func evaluate_group(
	special_gems: Array,
	color_id: String,
	group_size: int,
	equipped_gems: Array[SpecialGemDefinition],
	available_energy: int
) -> Dictionary:
	var definitions: Dictionary = {}
	for definition in equipped_gems:
		if definition != null:
			definitions[definition.id] = definition

	var effects: Array = []
	var inactive_gems: Array = []
	var remaining_energy: int = max(0, available_energy)
	var energy_spent: int = 0

	for gem_entry in special_gems:
		if typeof(gem_entry) != TYPE_DICTIONARY:
			continue
		var gem_id: String = str(gem_entry.get("special_gem_id", ""))
		var definition: SpecialGemDefinition = definitions.get(gem_id)
		if definition == null:
			push_error("Special gem '%s' is present in a match but is not in the equipped loadout." % gem_id)
			inactive_gems.append(_inactive_entry(gem_entry, false))
			continue

		var parameters: Dictionary = definition.effect_parameters
		var effect_type: String = definition.effect_type
		if not _is_supported_effect(effect_type):
			push_error("Unsupported special gem effect type '%s' for gem '%s'." % [effect_type, gem_id])
			inactive_gems.append(_inactive_entry(gem_entry, definition.remove_when_inactive))
			continue
		if not _has_valid_effect_parameters(definition):
			push_error("Special gem '%s' has invalid parameters for effect '%s'." % [gem_id, effect_type])
			inactive_gems.append(_inactive_entry(gem_entry, definition.remove_when_inactive))
			continue
		if (
			definition.color_id != color_id
			or group_size < definition.minimum_match_size
			or remaining_energy < definition.energy_cost
		):
			inactive_gems.append(_inactive_entry(gem_entry, definition.remove_when_inactive))
			continue

		if (
			definition.activation_chance < 1.0
			and rng.randf() >= definition.activation_chance
		):
			inactive_gems.append(_inactive_entry(gem_entry, definition.remove_when_inactive))
			continue

		effects.append({
			"gem_id": gem_id,
			"effect_type": effect_type,
			"effect_parameters": parameters.duplicate(true),
			"cell_position": gem_entry.get("cell_position", Vector2i(-1, -1)),
		})
		remaining_energy -= definition.energy_cost
		energy_spent += definition.energy_cost

	return {
		"effects": effects,
		"inactive_gems": inactive_gems,
		"energy_spent": energy_spent,
	}

func _inactive_entry(gem_entry: Dictionary, remove_when_inactive: bool) -> Dictionary:
	return {
		"gem_id": str(gem_entry.get("special_gem_id", "")),
		"cell_position": gem_entry.get("cell_position", Vector2i(-1, -1)),
		"remove_when_inactive": remove_when_inactive,
	}

func _is_supported_effect(effect_type: String) -> bool:
	return effect_type in ["critical_chance", "fireball", "barrier"]

func _has_valid_effect_parameters(definition: SpecialGemDefinition) -> bool:
	match definition.effect_type:
		"critical_chance":
			return float(definition.effect_parameters.get("critical_multiplier", 0.0)) >= 1.0
		"fireball":
			return int(definition.effect_parameters.get("damage", 0)) > 0
		"barrier":
			return int(definition.effect_parameters.get("guard", 0)) > 0
		_:
			return false
