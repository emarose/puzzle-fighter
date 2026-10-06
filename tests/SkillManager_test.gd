extends SceneTree

func _init() -> void:
    var manager: SkillManager = SkillManager.new()
    var combat_manager: CombatManager = CombatManager.new()

    combat_manager.register_actor("player", 100, 100)
    combat_manager.register_actor("enemy", 100, 100)

    var insufficient_energy: Dictionary = manager.execute_skill("burst", combat_manager, "player", "enemy")
    assert(insufficient_energy.get("success", true) == false)
    assert(insufficient_energy.get("reason", "") == "insufficient_energy")

    manager.add_energy("player", 3)
    var result: Dictionary = manager.execute_skill("burst", combat_manager, "player", "enemy")

    assert(result.get("success", false) == true)
    assert(result.get("amount", 0) > 0)
    assert(combat_manager.get_actor_hp("enemy") < 100)
    assert(manager.get_energy("player") == 0)

    combat_manager.resolve_attack("enemy", "player", "yellow", 3)
    assert(manager.get_energy("enemy") > 0)

    print("SkillManager_test passed")
    quit()
