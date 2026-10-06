extends SceneTree

func _init() -> void:
    var sequence: EnemyActionSequence = EnemyActionSequence.new()
    var first_turn: Array = sequence.get_actions(0, 6)
    var second_turn: Array = sequence.get_actions(1, 6)
    var third_turn: Array = sequence.get_actions(2, 6)
    assert(first_turn.size() == 6)
    assert(first_turn[0].get("name", "") == "spawn")
    assert(first_turn[0].get("color", "") == "red")
    assert(second_turn[0].get("color", "") == "blue")
    assert(first_turn[0].get("column", -1) != second_turn[0].get("column", -1))
    assert(third_turn[0].get("shape", [])[1] == Vector2i.DOWN)
    assert(first_turn[1].get("name", "") == "move")
    assert(first_turn[2].get("name", "") == "rotate")
    assert(first_turn[3].get("name", "") == "fall")
    assert(first_turn[4].get("name", "") == "lock")
    assert(first_turn[5].get("name", "") == "resolve")

    var custom_pattern: EnemyTurnPattern = EnemyTurnPattern.new()
    custom_pattern.color_sequence = ["yellow"]
    custom_pattern.preferred_column_step = 1
    custom_pattern.vertical_piece_every = 2
    var custom_first_turn: Array = sequence.get_actions(0, 6, custom_pattern)
    var custom_second_turn: Array = sequence.get_actions(1, 6, custom_pattern)
    assert(custom_first_turn[0].get("color", "") == "yellow")
    assert(custom_first_turn[0].get("column", -1) == 0)
    assert(custom_second_turn[0].get("shape", [])[1] == Vector2i.DOWN)
    print("EnemyActionSequence_test passed")
    quit()
