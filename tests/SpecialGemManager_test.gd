extends SceneTree

func _init() -> void:
	var critical: SpecialGemDefinition = SpecialGemDefinition.new(
		"critical",
		"Critical",
		"red",
		"critical_chance"
	)
	critical.minimum_match_size = 5
	critical.activation_chance = 1.0
	critical.effect_parameters = {"critical_multiplier": 2.0}

	var fireball: SpecialGemDefinition = SpecialGemDefinition.new(
		"fireball",
		"Fireball",
		"yellow",
		"fireball"
	)
	fireball.minimum_match_size = 4
	fireball.energy_cost = 3
	fireball.effect_parameters = {"damage": 20}

	var fireball_echo: SpecialGemDefinition = SpecialGemDefinition.new(
		"fireball_echo",
		"Fireball Echo",
		"yellow",
		"fireball"
	)
	fireball_echo.minimum_match_size = 4
	fireball_echo.effect_parameters = {"damage": 10}

	var barrier: SpecialGemDefinition = SpecialGemDefinition.new(
		"barrier",
		"Barrier",
		"blue",
		"barrier"
	)
	barrier.minimum_match_size = 4
	barrier.effect_parameters = {"guard": 4}

	var loadout: Array[SpecialGemDefinition] = [critical, fireball, fireball_echo, barrier]
	var manager: SpecialGemManager = SpecialGemManager.new()
	manager.rng.seed = 12345

	var critical_result: Dictionary = manager.evaluate_group(
		[{"special_gem_id": "critical", "cell_position": Vector2i(0, 0)}],
		"red",
		5,
		loadout,
		0
	)
	assert(critical_result.effects.size() == 1)
	assert(critical_result.effects[0].effect_type == "critical_chance")

	var fireball_result: Dictionary = manager.evaluate_group(
		[{"special_gem_id": "fireball", "cell_position": Vector2i(1, 1)}],
		"yellow",
		4,
		loadout,
		3
	)
	assert(fireball_result.effects.size() == 1)
	assert(fireball_result.energy_spent == 3)

	var multiple_gem_result: Dictionary = manager.evaluate_group(
		[
			{"special_gem_id": "fireball", "cell_position": Vector2i(1, 1)},
			{"special_gem_id": "fireball_echo", "cell_position": Vector2i(2, 1)},
		],
		"yellow",
		4,
		loadout,
		3
	)
	assert(multiple_gem_result.effects.size() == 2)
	assert(multiple_gem_result.energy_spent == 3)

	var barrier_result: Dictionary = manager.evaluate_group(
		[{"special_gem_id": "barrier", "cell_position": Vector2i(4, 4)}],
		"blue",
		4,
		loadout,
		0
	)
	assert(barrier_result.effects.size() == 1)
	assert(barrier_result.effects[0].effect_type == "barrier")

	var insufficient_energy: Dictionary = manager.evaluate_group(
		[{"special_gem_id": "fireball", "cell_position": Vector2i(2, 2)}],
		"yellow",
		4,
		loadout,
		2
	)
	assert(insufficient_energy.effects.is_empty())
	assert(insufficient_energy.energy_spent == 0)

	var fireball_gem: SpecialGemDefinition = SpecialGemDefinition.new("fireball", "Fireball", "yellow", "fireball")
	fireball_gem.minimum_match_size = 4
	fireball_gem.energy_cost = 3
	fireball_gem.short_label = "f"
	assert(fireball_gem.get_short_label() == "F")
	assert(fireball_gem.get_requirement_text() == "4+ 3E")
	assert(manager.requirements_met(fireball_gem, "yellow", 4, 3))
	assert(not manager.requirements_met(fireball_gem, "yellow", 3, 3))
	assert(not manager.requirements_met(fireball_gem, "yellow", 4, 2))
	assert(not manager.requirements_met(fireball_gem, "red", 4, 3))

	print("SpecialGemManager_test passed")
	quit()
