extends Node

@onready var battle_manager: Node = $BattleManager
@onready var board_manager: Node = $BoardManager
@onready var enemy_controller: Node = $EnemyController
@onready var player_piece_view: PieceView = $PlayerBoardContainer/PieceView

var piece_spawner: PieceSpawner = PieceSpawner.new()
var active_piece: Piece

func _ready() -> void:
	if battle_manager == null:
		battle_manager = get_node_or_null("BattleManager")
	if board_manager == null:
		board_manager = get_node_or_null("BoardManager")
	if enemy_controller == null:
		enemy_controller = get_node_or_null("EnemyController")

	if battle_manager != null:
		battle_manager.state_changed.connect(_on_battle_state_changed)
		battle_manager.start_battle()

	if enemy_controller != null and enemy_controller.has_method("bind_battle_and_controller"):
		enemy_controller.bind_battle_and_controller(battle_manager, self)

	_initialize_board()
	_spawn_piece()

func _on_battle_state_changed(old_state: int, new_state: int) -> void:
	if new_state == BattleManager.BattleState.ENEMY_ACTION and enemy_controller != null and enemy_controller.has_method("execute_turn"):
		enemy_controller.execute_turn()
		return

	if new_state == BattleManager.BattleState.PLAYING and active_piece == null:
		_spawn_piece()

func _initialize_board() -> void:
	if board_manager != null:
		board_manager.reset_board(Vector2i(6, 10))

func _spawn_piece(color_id: String = "red") -> bool:
	if board_manager == null:
		return false

	var spawn_position := Vector2i(1, 0)
	active_piece = piece_spawner.create_piece(color_id, spawn_position, [Vector2i(0, 0), Vector2i(1, 0)])

	if not board_manager.can_place_block_positions(active_piece.get_block_positions(), Vector2i.ZERO):
		if battle_manager != null:
			battle_manager.set_state(BattleManager.BattleState.DEFEAT)
		return false

	active_piece.spawn()
	if player_piece_view != null and player_piece_view.has_method("show_piece"):
		player_piece_view.show_piece(active_piece)
	return true

func spawn_enemy_piece(color_id: String = "green") -> bool:
	return _spawn_piece(color_id)

func enemy_move(direction: Vector2i) -> bool:
	return try_move(direction)

func enemy_rotate(clockwise: bool = true) -> bool:
	return try_rotate(clockwise)

func lock_enemy_piece() -> bool:
	return lock_active_piece()

func resolve_enemy_board() -> bool:
	var cascade_count: int = board_manager.resolve_cascade()
	return cascade_count >= 0

func execute_enemy_sequence(actions: Array = []) -> bool:
	if enemy_controller != null and enemy_controller.has_method("execute_turn"):
		return bool(enemy_controller.execute_turn())
	return false

func try_move(direction: Vector2i) -> bool:
	if active_piece == null:
		return false

	if battle_manager != null and not (battle_manager.can_player_act() or battle_manager.can_enemy_act()):
		return false

	var candidate_positions: Array = []
	for position in active_piece.get_block_positions():
		candidate_positions.append(position + direction)

	if not board_manager.can_place_block_positions(candidate_positions, Vector2i.ZERO):
		return false

	active_piece.logical_position += direction
	if player_piece_view != null and player_piece_view.has_method("show_piece"):
		player_piece_view.show_piece(active_piece)
	return true

func try_rotate(clockwise: bool = true) -> bool:
	if active_piece == null:
		return false

	if battle_manager != null and not (battle_manager.can_player_act() or battle_manager.can_enemy_act()):
		return false

	var original_positions: Array = active_piece.get_block_positions()
	var rotated: Array = []

	for offset in active_piece.blocks:
		var local_position: Vector2i = offset.get("local_position", Vector2i.ZERO)
		var next_offset: Vector2i = local_position
		if clockwise:
			next_offset = Vector2i(-next_offset.y, next_offset.x)
		else:
			next_offset = Vector2i(next_offset.y, -next_offset.x)
		rotated.append(active_piece.logical_position + next_offset)

	if not board_manager.can_place_block_positions(rotated, Vector2i.ZERO):
		return false

	if clockwise:
		active_piece.rotate_clockwise()
	else:
		active_piece.rotate_counter_clockwise()

	if player_piece_view != null and player_piece_view.has_method("show_piece"):
		player_piece_view.show_piece(active_piece)
	return true

func hard_drop() -> bool:
	if active_piece == null:
		return false

	while true:
		var next_position := active_piece.logical_position + Vector2i(0, 1)
		var candidate_positions: Array = []
		for position in active_piece.get_block_positions():
			candidate_positions.append(position + Vector2i(0, 1))

		if not board_manager.can_place_block_positions(candidate_positions, Vector2i.ZERO):
			break

		active_piece.logical_position = next_position

	return lock_active_piece()

func lock_active_piece() -> bool:
	if active_piece == null:
		return false

	var locked_positions: Array = board_manager.lock_piece(
		active_piece.get_block_positions(),
		Vector2i.ZERO,
		active_piece.color_id,
		active_piece.id
	)

	if locked_positions.is_empty():
		return false

	active_piece.lock()
	if player_piece_view != null and player_piece_view.has_method("clear_piece"):
		player_piece_view.clear_piece()
	active_piece = null

	var cascade_count: int = board_manager.resolve_cascade()
	if battle_manager != null and battle_manager.current_state != BattleManager.BattleState.ENEMY_ACTION:
		battle_manager.set_state(BattleManager.BattleState.RESOLVING)

	if battle_manager != null and battle_manager.current_state != BattleManager.BattleState.ENEMY_ACTION:
		battle_manager.set_state(BattleManager.BattleState.ENEMY_ACTION)
		return true

	return true
