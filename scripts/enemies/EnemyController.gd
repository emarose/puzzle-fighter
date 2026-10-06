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
var action_sequence: EnemyActionSequence = EnemyActionSequence.new()
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
	if battle_manager != null:
		player_state = CombatState.new(
			battle_manager.player_character.id,
			battle_manager.player_character.max_hp
		)
		enemy_state = CombatState.new(
			battle_manager.enemy_character.id,
			battle_manager.enemy_character.max_hp
		)
		combat_manager.set_actor_attack_modifiers(player_state.actor_id, battle_manager.player_character.attack_modifiers)
		combat_manager.set_actor_attack_modifiers(enemy_state.actor_id, battle_manager.enemy_character.attack_modifiers)
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

func prepare_combat() -> void:
	_register_combat_actors()

func sync_combat_states() -> void:
	_sync_combat_states()

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
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.emit("enemy_action_started", {"turn": turn_counter})
	if battle_controller == null or not is_enemy_ready():
		_finish_turn(false)
		return false
	if enemy_state.is_defeated() or battle_manager == null or not battle_manager.can_enemy_act():
		_finish_turn(false)
		return false

	var actions: Array = action_sequence.get_actions(turn_counter, enemy_board_manager.columns)
	var planned_drop: Dictionary = _choose_drop_plan(actions[0])
	if planned_drop.is_empty():
		_finish_turn(false)
		return false

	var success: bool = true
	for action in actions:
		match str(action.get("name", "")):
			"spawn":
				success = _spawn_enemy_piece(str(planned_drop["color"]), int(action["start_column"]))
				current_attack_preview = "dropping %s" % str(planned_drop["color"]).capitalize()
			"move":
				while active_piece != null and active_piece.logical_position.x != int(planned_drop["column"]):
					var horizontal_step: int = 1 if active_piece.logical_position.x < int(planned_drop["column"]) else -1
					if not _try_move_horizontal(horizontal_step):
						current_attack_preview = "blocked, dropping from current lane"
						break
					await get_tree().create_timer(fall_step_seconds).timeout
			"rotate":
				if planned_drop.shape[1] == Vector2i.DOWN:
					if not _rotate_active_piece():
						current_attack_preview = "rotation blocked, dropping horizontal piece"
			"fall":
				while _try_move_down():
					await get_tree().create_timer(fall_step_seconds).timeout
			"lock":
				success = _lock_active_piece()
			"resolve":
				var cascade_result: CascadeManager.CascadeResult = enemy_board_manager.resolve_cascade_result(enemy_state.actor_id)
				_refresh_enemy_board()
				if cascade_result.total_blocks_destroyed > 0:
					_resolve_enemy_matches(cascade_result)
				else:
					current_attack_preview = "locked %s, no match" % str(planned_drop["color"]).capitalize()
			_:
				success = false
		if not success:
			break

	_finish_turn(success)
	return success

func _choose_drop_plan(preferred_plan: Dictionary) -> Dictionary:
	if enemy_board_manager == null:
		return {}

	var preferred_color: String = str(preferred_plan.get("color", "red"))
	var preferred_column: int = int(preferred_plan.get("column", 0))
	var preferred_shape: Array = preferred_plan.get("shape", [Vector2i.ZERO, Vector2i.RIGHT])
	var alternate_shape: Array = [Vector2i.ZERO, Vector2i.DOWN] if preferred_shape[1] == Vector2i.RIGHT else [Vector2i.ZERO, Vector2i.RIGHT]
	var best_plan: Dictionary = {}
	var best_score: int = -1
	for shape in [preferred_shape, alternate_shape]:
		for color_id in ENEMY_COLORS:
			for column in range(enemy_board_manager.columns):
				var landing_origin: Vector2i = _find_landing_origin(column, shape)
				if landing_origin.x < 0:
					continue
				var positions: Array = _positions_for_piece(landing_origin, shape)
				var score: int = _count_matching_neighbors(color_id, positions) * 100
				if color_id == preferred_color:
					score += 10
				if column == preferred_column:
					score += 5
				if shape == preferred_shape:
					score += 2
				if score > best_score:
					best_score = score
					best_plan = {"color": color_id, "column": column, "shape": shape}
	return best_plan

func _find_landing_origin(column: int, shape: Array) -> Vector2i:
	var origin := Vector2i(column, 0)
	if not enemy_board_manager.can_place_block_positions(_positions_for_piece(origin, shape)):
		return Vector2i(-1, -1)
	while enemy_board_manager.can_place_block_positions(_positions_for_piece(origin + Vector2i.DOWN, shape)):
		origin += Vector2i.DOWN
	return origin

func _positions_for_piece(origin: Vector2i, shape: Array) -> Array:
	var positions: Array = []
	for offset in shape:
		positions.append(origin + offset)
	return positions

func _count_matching_neighbors(color_id: String, positions: Array) -> int:
	var count: int = 0
	for position in positions:
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor_position: Vector2i = position + direction
			if positions.has(neighbor_position):
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
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.emit("piece_spawned", {"actor_id": enemy_state.actor_id, "piece_id": active_piece.id, "color": color_id, "position": active_piece.logical_position})
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
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.emit("piece_moved", {"actor_id": enemy_state.actor_id, "piece_id": active_piece.id, "position": active_piece.logical_position})
	return true

func _try_move_horizontal(direction_x: int) -> bool:
	if active_piece == null:
		return false
	var direction := Vector2i(direction_x, 0)
	var candidate_positions: Array = []
	for position in active_piece.get_block_positions():
		candidate_positions.append(position + direction)
	if not enemy_board_manager.can_place_block_positions(candidate_positions):
		return false
	active_piece.logical_position += direction
	enemy_piece_view.show_piece(active_piece)
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.emit("piece_moved", {"actor_id": enemy_state.actor_id, "piece_id": active_piece.id, "position": active_piece.logical_position})
	return true

func _rotate_active_piece() -> bool:
	if active_piece == null:
		return false
	var rotated_positions: Array = []
	for block in active_piece.blocks:
		var local_position: Vector2i = block.get("local_position", Vector2i.ZERO)
		rotated_positions.append(active_piece.logical_position + Vector2i(-local_position.y, local_position.x))
	if not enemy_board_manager.can_place_block_positions(rotated_positions):
		return false
	active_piece.rotate_clockwise()
	enemy_piece_view.show_piece(active_piece)
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.emit("piece_rotated", {"actor_id": enemy_state.actor_id, "piece_id": active_piece.id, "orientation": active_piece.orientation})
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
	var locked_piece_id: String = active_piece.id
	active_piece = null
	enemy_piece_view.clear_piece()
	_refresh_enemy_board()
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.emit("piece_locked", {"actor_id": enemy_state.actor_id, "piece_id": locked_piece_id, "positions": locked_positions})
	return true

func _resolve_enemy_matches(cascade_result: CascadeManager.CascadeResult) -> void:
	var effect_summaries: Array[String] = []
	_register_combat_actors()
	for candidate_color in ENEMY_COLORS:
		var matched_block_count: int = int(cascade_result.color_block_counts.get(candidate_color, 0))
		if matched_block_count <= 0:
			continue
		var event: CombatManager.AttackEvent = combat_manager.create_attack_event(
			enemy_state.actor_id,
			player_state.actor_id,
			candidate_color,
			matched_block_count,
			cascade_result.cascade_count,
			cascade_result.combo_multiplier,
			[]
		)
		combat_manager.apply_attack_event(event)
		effect_summaries.append(_describe_effect(event, "Enemy"))
	_sync_combat_states()
	current_attack_preview = "; ".join(effect_summaries)

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

func _finish_turn(success: bool = true) -> void:
	turn_counter += 1
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.emit("enemy_action_finished", {"turn": turn_counter - 1, "success": success})
	if battle_manager != null:
		battle_manager.register_outcome(player_state.current_hp, enemy_state.current_hp)
