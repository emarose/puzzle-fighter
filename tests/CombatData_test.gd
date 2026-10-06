extends SceneTree

func _init() -> void:
	var player: CharacterDefinition = load("res://resources/characters/default_player.tres")
	var enemy: EnemyDefinition = load("res://resources/enemies/default_enemy.tres")
	var tuning: CombatTuning = load("res://resources/combat_tuning.tres")
	var catalog: SkillCatalog = load("res://resources/skills/default_skill_catalog.tres")

	assert(player.max_hp == 200)
	assert(player.starting_guard == 0)
	assert(player.starting_energy == 0)
	assert(player.skill_ids == ["burst", "heal", "pulse"])
	assert(enemy.max_hp == 200)
	assert(enemy.turn_pattern.color_sequence.size() == 8)
	assert(tuning.damage_floor == 50)
	assert(tuning.max_energy == 9)
	assert(tuning.color_definitions.size() == 4)
	assert(tuning.get_color_palette().size() == 4)
	assert(catalog.skills.size() == 3)

	var skills: SkillManager = SkillManager.new(catalog, tuning)
	assert(skills.skill_definitions.size() == 3)
	assert(skills.get_skill("burst").cost == 3)
	assert(skills.add_energy(player.id, 99) == tuning.max_energy)

	var combat: CombatManager = CombatManager.new(tuning)
	combat.register_actor(player.id, player.max_hp)
	combat.register_actor(enemy.id, enemy.max_hp)
	combat.set_actor_attack_modifiers(player.id, {"red": 1.0})
	var attack: CombatManager.AttackEvent = combat.create_attack_event(player.id, enemy.id, "red", 1)
	assert(attack.amount == tuning.damage_floor)
	var guard_event: CombatManager.AttackEvent = combat.create_attack_event(player.id, player.id, "blue", 10)
	assert(guard_event.amount == 3)

	print("CombatData_test passed")
	quit()
