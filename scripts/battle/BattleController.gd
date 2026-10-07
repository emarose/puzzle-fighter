extends Node

@onready var battle_manager: Node = $BattleManager
@onready var board_manager: Node = $BoardManager
@onready var enemy_controller: Node = $EnemyController
@onready var player_piece_view: PieceView = $PlayerBoardContainer/PieceView
@onready var enemy_board_manager: Node = $EnemyBoardContainer.get_node_or_null("BoardManager")

@export var fall_interval: float = 0.75

var piece_spawner: PieceSpawner = PieceSpawner.new()
var active_piece: Piece
var event_bus: EventBus
var fall_timer: float = 0.0
var combat_manager: CombatManager = CombatManager.new()
var skill_manager: SkillManager = SkillManager.new()

func _ready() -> void:
	event_bus = EventBus.get_instance()
	if battle_manager == null:
		battle_manager = get_node_or_null("BattleManager")
	if board_manager == null:
		board_manager = get_node_or_null("BoardManager")
	if enemy_controller == null:
		enemy_controller = get_node_or_null("EnemyController")

	if battle_manager != null:
		battle_manager.state_changed.connect(_on_battle_state_changed)
		battle_manager.start_battle()
		combat_manager.configure(battle_manager.combat_tuning)
		skill_manager.configure(battle_manager.skill_catalog, battle_manager.combat_tuning)

	var player_board_view: Node2D = get_node_or_null("PlayerBoardContainer/BoardView")
	if player_board_view != null:
		player_board_view.board_manager = board_manager

	if enemy_controller != null and enemy_controller.has_method("bind_battle_and_controller"):
		enemy_controller.bind_battle_and_controller(battle_manager, self)
		combat_manager.set_actor_attack_modifiers(
			enemy_controller.player_state.actor_id,
			battle_manager.player_character.attack_modifiers
		)
		combat_manager.set_actor_attack_modifiers(
			enemy_controller.enemy_state.actor_id,
			battle_manager.enemy_character.attack_modifiers
		)
		combat_manager.set_actor_guard(
			enemy_controller.player_state.actor_id,
			battle_manager.player_character.starting_guard
		)
		skill_manager.set_energy(
			enemy_controller.player_state.actor_id,
			battle_manager.player_character.starting_energy
		)
		skill_manager.set_energy(
			enemy_controller.enemy_state.actor_id,
			battle_manager.enemy_character.starting_energy
		)

	_initialize_board()
	_spawn_piece()

func _process(delta: float) -> void:
	if active_piece == null:
		return
	if battle_manager == null:
		return
	if not battle_manager.can_player_act():
		return

	fall_timer += delta
	if fall_timer >= fall_interval:
		fall_timer = 0.0
		if not try_move(Vector2i(0, 1)):
			await lock_active_piece()

func _on_battle_state_changed(_old_state: int, new_state: int) -> void:
	if new_state == BattleManager.BattleState.ENEMY_ACTION:
		if enemy_controller == null or not enemy_controller.has_method("execute_turn"):
			if battle_manager != null:
				battle_manager.set_state(BattleManager.BattleState.PLAYING)
			return
		if enemy_board_manager == null or not enemy_controller.has_method("is_enemy_ready") or not enemy_controller.is_enemy_ready():
			if battle_manager != null:
				battle_manager.set_state(BattleManager.BattleState.PLAYING)
			return
		await enemy_controller.execute_turn()
		return

	if new_state == BattleManager.BattleState.PLAYING and active_piece == null:
		if enemy_controller != null and enemy_controller.has_method("is_enemy_turn_in_progress") and enemy_controller.is_enemy_turn_in_progress():
			return
		_spawn_piece()

func _initialize_board() -> void:
	if battle_manager != null and board_manager != null:
		board_manager.combat_tuning = battle_manager.combat_tuning
	if battle_manager != null and enemy_board_manager != null:
		enemy_board_manager.combat_tuning = battle_manager.combat_tuning
	if board_manager != null:
		board_manager.reset_board(Vector2i(6, 10))
	if enemy_board_manager != null:
		enemy_board_manager.reset_board(Vector2i(6, 10))
	_refresh_board_views()

func _refresh_board_views() -> void:
	var player_board_view: Node2D = get_node_or_null("PlayerBoardContainer/BoardView")
	if player_board_view != null:
		player_board_view.queue_redraw()
	var enemy_board_view: Node2D = get_node_or_null("EnemyBoardContainer/BoardView")
	if enemy_board_view != null:
		enemy_board_view.queue_redraw()

func get_player_skill_definitions() -> Array[SkillDefinition]:
	var definitions: Array[SkillDefinition] = []
	if battle_manager == null:
		return definitions
	for skill_id in battle_manager.player_character.skill_ids:
		var definition: SkillDefinition = skill_manager.get_skill(skill_id)
		if definition != null:
			definitions.append(definition)
	return definitions

func get_skill_for_slot(slot_index: int) -> String:
	var definitions: Array[SkillDefinition] = get_player_skill_definitions()
	if slot_index < 0 or slot_index >= definitions.size():
		return ""
	return definitions[slot_index].id

func use_skill_slot(slot_index: int) -> bool:
	var skill_id: String = get_skill_for_slot(slot_index)
	if skill_id.is_empty():
		return false
	return use_skill(skill_id)

func get_skill_energy() -> int:
	return skill_manager.get_energy(_player_actor_id())

func get_player_guard() -> int:
	if enemy_controller == null or enemy_controller.player_state == null:
		return 0
	return enemy_controller.combat_manager.get_actor_guard(_player_actor_id())

func get_enemy_guard() -> int:
	if enemy_controller == null or enemy_controller.enemy_state == null:
		return 0
	return enemy_controller.combat_manager.get_actor_guard(enemy_controller.enemy_state.actor_id)

func get_enemy_energy() -> int:
	if enemy_controller == null or enemy_controller.enemy_state == null:
		return 0
	return skill_manager.get_energy(enemy_controller.enemy_state.actor_id)

func get_max_energy() -> int:
	return skill_manager.max_energy

func get_skill_cost(skill_id: String) -> int:
	var definition: SkillDefinition = skill_manager.get_skill(skill_id)
	return definition.cost if definition != null else -1

func can_use_skill(skill_id: String) -> bool:
	var cost: int = get_skill_cost(skill_id)
	return (
		cost >= 0
		and battle_manager != null
		and enemy_controller != null
		and battle_manager.player_character.skill_ids.has(skill_id)
		and battle_manager.can_player_act()
		and get_skill_energy() >= cost
	)

func _player_actor_id() -> String:
	if enemy_controller != null and enemy_controller.player_state != null:
		return enemy_controller.player_state.actor_id
	return "player"

func use_skill(skill_id: String) -> bool:
	if not can_use_skill(skill_id) or enemy_controller == null:
		return false
	return _execute_actor_skill(
		skill_id,
		enemy_controller.player_state.actor_id,
		enemy_controller.enemy_state.actor_id
	)

func use_enemy_skill(skill_id: String) -> bool:
	if (
		battle_manager == null
		or not battle_manager.can_enemy_act()
		or enemy_controller == null
		or not battle_manager.enemy_character.skill_ids.has(skill_id)
		or get_skill_cost(skill_id) < 0
		or skill_manager.get_energy(enemy_controller.enemy_state.actor_id) < get_skill_cost(skill_id)
	):
		return false
	return _execute_actor_skill(
		skill_id,
		enemy_controller.enemy_state.actor_id,
		enemy_controller.player_state.actor_id
	)

func _execute_actor_skill(skill_id: String, source_actor_id: String, target_actor_id: String) -> bool:
	enemy_controller.prepare_combat()
	var result: Dictionary = skill_manager.execute_skill(
		skill_id,
		enemy_controller.combat_manager,
		source_actor_id,
		target_actor_id
	)
	if not bool(result.get("success", false)):
		return false

	enemy_controller.sync_combat_states()
	battle_manager.register_outcome(enemy_controller.player_state.current_hp, enemy_controller.enemy_state.current_hp)
	return true

func _apply_player_cascade_effects(cascade_result: CascadeManager.CascadeResult) -> void:
	if cascade_result == null or cascade_result.total_blocks_destroyed <= 0 or enemy_controller == null:
		return

	enemy_controller.prepare_combat()
	for color_id in combat_manager.get_color_ids():
		var matched_block_count: int = int(cascade_result.color_block_counts.get(color_id, 0))
		if matched_block_count <= 0:
			continue
		var attack_event: CombatManager.AttackEvent = combat_manager.create_attack_event(
			enemy_controller.player_state.actor_id,
			enemy_controller.enemy_state.actor_id,
			color_id,
			matched_block_count,
			cascade_result.cascade_count,
			cascade_result.combo_multiplier,
			[]
		)
		enemy_controller.apply_attack_event(attack_event)
		battle_manager.register_outcome(enemy_controller.player_state.current_hp, enemy_controller.enemy_state.current_hp)
		if battle_manager.current_state == BattleManager.BattleState.VICTORY:
			return

func _spawn_piece() -> bool:
	if board_manager == null or battle_manager == null:
		return false

	var spawn_position := Vector2i(1, 0)
	active_piece = piece_spawner.create_random_piece(
		battle_manager.player_character.available_colors,
		spawn_position
	)
	if active_piece == null:
		return false

	if not board_manager.can_place_block_positions(active_piece.get_block_positions(), Vector2i.ZERO):
		if battle_manager != null:
			battle_manager.set_state(BattleManager.BattleState.DEFEAT)
		return false

	active_piece.spawn()
	if event_bus != null:
		event_bus.emit("piece_spawned", {
			"piece_id": active_piece.id,
			"colors": active_piece.get_color_ids(),
			"position": active_piece.logical_position,
		})
	if player_piece_view != null and player_piece_view.has_method("show_piece"):
		player_piece_view.show_piece(active_piece)
	_refresh_board_views()
	return true

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
	if event_bus != null:
		event_bus.emit("piece_moved", {"actor_id": _player_actor_id(), "piece_id": active_piece.id, "position": active_piece.logical_position})
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
	_refresh_board_views()
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

	call_deferred("_lock_active_piece_after_drop")
	return true

func _lock_active_piece_after_drop() -> void:
	await lock_active_piece()

func lock_active_piece() -> bool:
	if active_piece == null:
		return false

	var locked_positions: Array = board_manager.lock_piece_blocks(
		active_piece.blocks,
		active_piece.logical_position,
		active_piece.id
	)

	if locked_positions.is_empty():
		return false

	active_piece.lock()
	if event_bus != null:
		event_bus.emit("piece_locked", {
			"piece_id": active_piece.id,
			"colors": active_piece.get_color_ids(),
			"position": active_piece.logical_position,
		})
	if player_piece_view != null and player_piece_view.has_method("clear_piece"):
		player_piece_view.clear_piece()
	active_piece = null
	_refresh_board_views()

	if battle_manager != null and battle_manager.current_state != BattleManager.BattleState.ENEMY_ACTION:
		battle_manager.set_state(BattleManager.BattleState.RESOLVING)

	var board_view: BoardView = get_node_or_null("PlayerBoardContainer/BoardView") as BoardView
	var highlight_callback: Callable = (
		Callable(board_view, "show_match_highlight")
		if board_view != null
		else Callable()
	)
	var cascade_result: CascadeManager.CascadeResult = await board_manager.resolve_cascade_animated_result(
		_player_actor_id(),
		highlight_callback
	)
	var cascade_count: int = cascade_result.cascade_count
	if event_bus != null:
		event_bus.emit("cascade_resolved", {"cascade_count": cascade_count, "total_blocks_destroyed": cascade_result.total_blocks_destroyed})
	_refresh_board_views()
	_apply_player_cascade_effects(cascade_result)
	if battle_manager != null and battle_manager.current_state == BattleManager.BattleState.VICTORY:
		return true
	if battle_manager != null and battle_manager.current_state != BattleManager.BattleState.ENEMY_ACTION:
		battle_manager.set_state(BattleManager.BattleState.ENEMY_ACTION)
		return true

	return true
