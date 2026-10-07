extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: BoardManager = BoardManager.new()
	board.reset_board(Vector2i(6, 10))
	for position in [
		Vector2i(0, 7),
		Vector2i(0, 8),
		Vector2i(1, 8),
		Vector2i(4, 7),
		Vector2i(4, 8),
		Vector2i(5, 8),
	]:
		var gem_id: String = "critical_chance" if position == Vector2i(0, 7) else ""
		board.set_cell(position, "red" if position.x < 3 else "blue", "", gem_id)

	board.prepared_groups = board.detect_prepared_groups_for_board()
	assert(board.prepared_groups.size() == 2)
	var original_red_id: int = _group_for_color(board, "red").id
	assert(_group_for_color(board, "red").special_gems.size() == 1)

	board.set_cell(Vector2i(1, 7), "red")
	board.prepared_groups = board.detect_prepared_groups_for_board()
	var grown_red: MatchManager.PreparedGroup = _group_for_color(board, "red")
	assert(grown_red.size == 4)
	assert(grown_red.id == original_red_id)
	assert(_group_for_color(board, "blue").size == 3)

	await board.resolve_cascade_animated_result("test")
	assert(_count_color(board, "red") == 4)
	assert(_group_for_color(board, "red").size == 4)

	var blue_id: int = _group_for_color(board, "blue").id
	var grown_red_after_scan: MatchManager.PreparedGroup = _group_for_color(board, "red")
	var resolve_result: Dictionary = board.resolve_prepared_group(grown_red_after_scan, "test", [Vector2i(0, 7)])
	assert(resolve_result.get("resolved", false))
	assert(resolve_result.get("blocks_removed", 0) == 3)
	assert(_count_color(board, "red") == 1)
	assert(board.get_cell(Vector2i(0, 9)).special_gem_id == "critical_chance")
	assert(_count_color(board, "blue") == 3)
	assert(_group_for_color(board, "blue").id == blue_id)

	print("PreparedGroups_test passed")
	quit()

func _group_for_color(board: BoardManager, color_id: String) -> MatchManager.PreparedGroup:
	for group in board.prepared_groups:
		if group is MatchManager.PreparedGroup and group.color_id == color_id:
			return group
	return null

func _count_color(board: BoardManager, color_id: String) -> int:
	var count: int = 0
	for y in range(board.rows):
		for x in range(board.columns):
			var cell: BoardCell = board.get_cell(Vector2i(x, y))
			if not cell.is_empty and cell.color_id == color_id:
				count += 1
	return count
