extends SceneTree

func _init() -> void:
	var board := BoardManager.new()
	board.reset_board(Vector2i(6, 10))
	board.set_cell(Vector2i(0, 0), "red")
	board.set_cell(Vector2i(1, 0), "red")
	board.set_cell(Vector2i(2, 0), "red")
	board.set_cell(Vector2i(0, 1), "blue")
	board.set_cell(Vector2i(0, 2), "green")

	var cascade_manager := CascadeManager.new()
	var result: CascadeManager.CascadeResult = cascade_manager.resolve(board)
	assert(result.cascade_count == 1)
	assert(result.total_blocks_destroyed == 3)
	assert(result.attack_power >= 3)

	quit()
