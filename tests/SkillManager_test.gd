extends SceneTree

func _init() -> void:
    var manager: SkillManager = SkillManager.new()
    var combat_manager: CombatManager = CombatManager.new()

    combat_manager.register_actor("player", 100, 100)
    combat_manager.register_actor("enemy", 100, 100)

    var result: Dictionary = manager.execute_skill("burst", combat_manager, "player", "enemy")

    assert(result.get("success", false) == true)
    assert(result.get("amount", 0) > 0)
    assert(combat_manager.get_actor_hp("enemy") < 100)

    print("SkillManager_test passed")
    quit()
