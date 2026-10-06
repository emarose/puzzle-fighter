extends SceneTree

func _init() -> void:
	var manager := CombatManager.new()
	manager.register_actor("player", 100)
	manager.register_actor("enemy", 80)

	var hp_after_damage := manager.apply_damage("enemy", 25)
	assert(hp_after_damage == 55)

	var event: CombatManager.AttackEvent = manager.create_attack_event("player", "enemy", "red", 10, 2, 1.5, ["burst"])
	assert(event.amount >= 10)
	assert(event.special_effects.has("burst"))

	manager.set_actor_attack_modifiers("player", {"red": 2.0})
	var modified_event: CombatManager.AttackEvent = manager.create_attack_event("player", "enemy", "red", 10)
	assert(modified_event.amount > manager.create_attack_event("enemy", "player", "red", 10).amount)

	manager.resolve_attack("player", "player", "blue", 10)
	var player_guard: int = manager.get_actor_guard("player")
	assert(player_guard > 0)
	var player_hp_before_guarded_hit: int = manager.get_actor_hp("player")
	manager.apply_damage("player", player_guard)
	assert(manager.get_actor_hp("player") == player_hp_before_guarded_hit)
	assert(manager.get_actor_guard("player") == 0)

	var energy_event: CombatManager.AttackEvent = manager.create_attack_event("enemy", "player", "yellow", 3)
	assert(energy_event.amount >= 1)

	quit()
