extends SceneTree

func _init() -> void:
    var sequence: EnemyActionSequence = EnemyActionSequence.new()
    assert(sequence.actions.size() >= 5)
    assert(sequence.actions[0].get("name", "") == "spawn")
    assert(sequence.actions[5].get("name", "") == "attack")
    print("EnemyActionSequence_test passed")
    quit()
