extends SceneTree

func _init() -> void:
	var spawner: PieceSpawner = PieceSpawner.new()
	spawner.rng.seed = 314159
	var available_colors: Array[String] = ["red", "blue", "green", "yellow"]
	var generated_mixed_pair: bool = false

	for _index in range(32):
		var random_piece: Piece = spawner.create_random_piece(available_colors)
		assert(random_piece != null)
		assert(random_piece.get_block_count() == 2)
		assert(available_colors.has(random_piece.get_block_color(0)))
		assert(available_colors.has(random_piece.get_block_color(1)))
		if random_piece.get_block_color(0) != random_piece.get_block_color(1):
			generated_mixed_pair = true
	assert(generated_mixed_pair)

	var mixed_piece: Piece = spawner.create_piece_with_colors(
		["red", "blue"],
		Vector2i(1, 1)
	)
	var board: BoardManager = BoardManager.new()
	board.reset_board(Vector2i(6, 10))
	var locked_positions: Array = board.lock_piece_blocks(
		mixed_piece.blocks,
		mixed_piece.logical_position,
		mixed_piece.id
	)
	assert(locked_positions.size() == 2)
	assert(board.get_cell(Vector2i(1, 1)).color_id == "red")
	assert(board.get_cell(Vector2i(2, 1)).color_id == "blue")

	var invalid_piece: Piece = spawner.create_piece_with_colors(
		["green", "yellow"],
		Vector2i(5, 9)
	)
	assert(board.lock_piece_blocks(invalid_piece.blocks, invalid_piece.logical_position).is_empty())
	assert(board.is_cell_empty(Vector2i(5, 9)))

	var legacy_piece: Piece = spawner.create_piece("green")
	assert(legacy_piece.get_block_color(0) == "green")
	assert(legacy_piece.get_block_color(1) == "green")

	print("PieceSpawner_test passed")
	quit()
