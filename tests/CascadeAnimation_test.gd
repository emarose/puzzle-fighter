extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var board: BoardManager = BoardManager.new()
	board.reset_board(Vector2i(6, 10))
	board.set_cell(Vector2i(0, 9), "red")
	board.set_cell(Vector2i(1, 9), "red")
	board.set_cell(Vector2i(2, 9), "red")

	var cascade_manager: CascadeManager = CascadeManager.new()
	var result: CascadeManager.CascadeResult = await cascade_manager.resolve_animated(
		board,
		MatchManager.new(),
		"test",
		null,
		Callable(self, "_wait_while_match_is_visible").bind(board)
	)
	assert(result.cascade_count == 1)
	assert(result.total_blocks_destroyed == 3)
	assert(board.get_cell(Vector2i(0, 9)).is_empty)

	print("CascadeAnimation_test passed")
	quit()

func _wait_while_match_is_visible(groups: Array, board: BoardManager) -> void:
	assert(groups.size() == 1)
	assert(groups[0].size() == 3)
	for position in groups[0]:
		assert(not board.get_cell(position).is_empty)
	await create_timer(0.05).timeout
