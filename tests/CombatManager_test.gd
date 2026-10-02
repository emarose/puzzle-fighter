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

	quit()
