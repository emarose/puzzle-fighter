class_name EnemyController
extends Node

var battle_manager: BattleManager
var battle_controller: Node
var enemy_board_manager: BoardManager
var enemy_piece_view: PieceView
var combat_manager: CombatManager = CombatManager.new()
var player_state: CombatState = CombatState.new("player", 100, 100)
var enemy_state: CombatState = CombatState.new("enemy", 100, 100)
var enemy_piece_spawner: PieceSpawner = PieceSpawner.new()
var active_piece: Piece
var current_attack_preview: String = "idle"
var turn_counter: int = 0
var enemy_board_ready: bool = false
var fall_step_seconds: float = 0.14

const ENEMY_COLORS: Array[String] = ["red", "blue", "green", "yellow"]

func _ready() -> void:
	battle_controller = get_parent()
	battle_manager = get_parent().get_node_or_null("BattleManager") as BattleManager
	enemy_board_manager = get_parent().get_node_or_null("EnemyBoardContainer/BoardManager") as BoardManager
	enemy_piece_view = get_parent().get_node_or_null("EnemyBoardContainer/PieceView") as PieceView
	enemy_board_ready = enemy_board_manager != null and enemy_piece_view != null
	_register_combat_actors()

func bind_battle_and_controller(p_battle_manager: Node, p_battle_controller: Node) -> void:
	battle_manager = p_battle_manager as BattleManager
	battle_controller = p_battle_controller
	if battle_controller != null:
		enemy_board_manager = battle_controller.get_node_or_null("EnemyBoardContainer/BoardManager") as BoardManager
		enemy_piece_view = battle_controller.get_node_or_null("EnemyBoardContainer/PieceView") as PieceView
	enemy_board_ready = enemy_board_manager != null and enemy_piece_view != null

func _register_combat_actors() -> void:
	combat_manager.register_actor(player_state.actor_id, player_state.max_hp, player_state.current_hp)
	combat_manager.register_actor(enemy_state.actor_id, enemy_state.max_hp, enemy_state.current_hp)

func is_enemy_ready() -> bool:
	return enemy_board_ready

func get_current_attack_preview() -> String:
	return current_attack_preview

func apply_attack_event(event: CombatManager.AttackEvent) -> bool:
	if event == null:
		return false

	_register_combat_actors()
	combat_manager.apply_attack_event(event)
	_sync_combat_states()
	current_attack_preview = _describe_effect(event, "Player")
	return true

func execute_turn() -> bool:
	if battle_controller == null or not is_enemy_ready():
		_finish_turn()
		return false
	if enemy_state.is_defeated() or battle_manager == null or not battle_manager.can_enemy_act():
		_finish_turn()
		return false

	var drop_plan: Dictionary = _choose_drop_plan()
	if drop_plan.is_empty() or not _spawn_enemy_piece(str(drop_plan["color"]), int(drop_plan["x"])):
		_finish_turn()
		return false

	current_attack_preview = "dropping %s" % str(drop_plan["color"]).capitalize()
	while _try_move_down():
		await get_tree().create_timer(fall_step_seconds).timeout

	if not _lock_active_piece():
		_finish_turn()
		return false

	var cascade_result: CascadeManager.CascadeResult = enemy_board_manager.resolve_cascade_result()
	_refresh_enemy_board()
	if cascade_result.total_blocks_destroyed > 0:
		_resolve_enemy_match(cascade_result)
	else:
		current_attack_preview = "locked %s, no match" % str(drop_plan["color"]).capitalize()

	_finish_turn()
	return true

func _choose_drop_plan() -> Dictionary:
	if enemy_board_manager == null:
		return {}

	var preferred_color: String = ENEMY_COLORS[turn_counter % ENEMY_COLORS.size()]
	var best_plan: Dictionary = {}
	var best_score: int = -1
	for color_id in ENEMY_COLORS:
		for column in range(enemy_board_manager.columns - 1):
			var landing_row: int = _find_landing_row(column)
			if landing_row < 0:
				continue
			var score: int = _count_matching_neighbors(color_id, column, landing_row)
			if color_id == preferred_color:
				score += 1
			if score > best_score:
				best_score = score
				best_plan = {"color": color_id, "x": column}
	return best_plan

func _find_landing_row(column: int) -> int:
	var row: int = 0
	var positions: Array = [Vector2i(column, row), Vector2i(column + 1, row)]
	if not enemy_board_manager.can_place_block_positions(positions):
		return -1
	while enemy_board_manager.can_place_block_positions([
		Vector2i(column, row + 1),
		Vector2i(column + 1, row + 1),
	]):
		row += 1
	return row

func _count_matching_neighbors(color_id: String, column: int, row: int) -> int:
	var count: int = 0
	for position in [Vector2i(column, row), Vector2i(column + 1, row)]:
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor_position: Vector2i = position + direction
			if neighbor_position == Vector2i(column, row) or neighbor_position == Vector2i(column + 1, row):
				continue
			if not enemy_board_manager.is_within_bounds(neighbor_position):
				continue
			var neighbor: BoardCell = enemy_board_manager.get_cell(neighbor_position)
			if not neighbor.is_empty and neighbor.color_id == color_id:
				count += 1
	return count

func _spawn_enemy_piece(color_id: String, column: int) -> bool:
	active_piece = enemy_piece_spawner.create_piece(color_id, Vector2i(column, 0))
	if not enemy_board_manager.can_place_block_positions(active_piece.get_block_positions()):
		active_piece = null
		return false
	active_piece.spawn()
	enemy_piece_view.show_piece(active_piece)
	return true

func _try_move_down() -> bool:
	if active_piece == null:
		return false
	var candidate_positions: Array = []
	for position in active_piece.get_block_positions():
		candidate_positions.append(position + Vector2i.DOWN)
	if not enemy_board_manager.can_place_block_positions(candidate_positions):
		return false
	active_piece.logical_position += Vector2i.DOWN
	enemy_piece_view.show_piece(active_piece)
	return true

func _lock_active_piece() -> bool:
	if active_piece == null:
		return false
	var locked_positions: Array = enemy_board_manager.lock_piece(
		active_piece.get_block_positions(),
		Vector2i.ZERO,
		active_piece.color_id,
		active_piece.id
	)
	if locked_positions.is_empty():
		return false
	active_piece.lock()
	active_piece = null
	enemy_piece_view.clear_piece()
	_refresh_enemy_board()
	return true

func _resolve_enemy_match(cascade_result: CascadeManager.CascadeResult) -> void:
	var color_id: String = ""
	var matched_block_count: int = 0
	for candidate_color in ENEMY_COLORS:
		var count: int = int(cascade_result.color_block_counts.get(candidate_color, 0))
		if count > matched_block_count:
			color_id = candidate_color
			matched_block_count = count
	if color_id.is_empty() or matched_block_count <= 0:
		return

	_register_combat_actors()
	var event: CombatManager.AttackEvent = combat_manager.resolve_attack(
		enemy_state.actor_id,
		player_state.actor_id,
		color_id,
		matched_block_count,
		cascade_result.cascade_count,
		cascade_result.combo_multiplier,
		[]
	)
	_sync_combat_states()
	current_attack_preview = _describe_effect(event, "Enemy")

func _sync_combat_states() -> void:
	enemy_state.current_hp = combat_manager.get_actor_hp(enemy_state.actor_id)
	player_state.current_hp = combat_manager.get_actor_hp(player_state.actor_id)

func _describe_effect(event: CombatManager.AttackEvent, actor_name: String) -> String:
	var definition: ColorDefinition = combat_manager.get_color_definition(event.color)
	if definition == null:
		return "%s effect: %d" % [actor_name, event.amount]
	match definition.combat_role:
		ColorDefinition.CombatRole.DAMAGE:
			return "%s dealt %d %s damage" % [actor_name, event.amount, event.color]
		ColorDefinition.CombatRole.DEFENSE:
			return "%s guarded with %s" % [actor_name, event.color]
		ColorDefinition.CombatRole.HEAL:
			return "%s restored %d HP" % [actor_name, event.amount]
		ColorDefinition.CombatRole.ENERGY:
			return "%s gained %d energy" % [actor_name, event.amount]
	return "%s effect: %d" % [actor_name, event.amount]

func _refresh_enemy_board() -> void:
	if enemy_board_manager == null:
		return
	var board_view: Node2D = enemy_board_manager.get_parent().get_node_or_null("BoardView")
	if board_view != null:
		board_view.queue_redraw()

func _finish_turn() -> void:
	turn_counter += 1
	if battle_manager != null:
		battle_manager.register_outcome(player_state.current_hp, enemy_state.current_hp)
