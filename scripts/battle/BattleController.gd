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
var special_gem_manager: SpecialGemManager = SpecialGemManager.new()

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
	_configure_gem_presentation()
	if event_bus != null:
		event_bus.event_emitted.connect(_on_gem_presentation_event)
	_spawn_piece()

func get_player_special_gems() -> Array[SpecialGemDefinition]:
	if battle_manager != null and battle_manager.player_character != null:
		var loadout: SpecialGemLoadout = battle_manager.player_character.special_gem_loadout
		if loadout != null:
			return loadout.get_equipped_gems()
	return []

func _configure_gem_presentation() -> void:
	var labels: Dictionary = {}
	for definition in get_player_special_gems():
		labels[definition.id] = definition.get_short_label()
	var board_view: BoardView = get_node_or_null("PlayerBoardContainer/BoardView") as BoardView
	if board_view != null:
		board_view.set_special_gem_presentation(labels, Callable(self, "get_special_gem_status_at"))
	if player_piece_view != null:
		player_piece_view.set_special_gem_labels(labels)

# Read-only readiness of the gem at `cell` for the board's badge styling.
func get_special_gem_status_at(cell: Vector2i) -> int:
	if board_manager == null:
		return SpecialGemGlyph.Status.IDLE
	var group: MatchManager.PreparedGroup = board_manager.find_prepared_group_for_cell(board_manager.prepared_groups, cell)
	if group == null:
		return SpecialGemGlyph.Status.IDLE
	var board_cell: BoardCell = board_manager.get_cell(cell)
	var definition: SpecialGemDefinition = null
	for candidate in get_player_special_gems():
		if candidate.id == board_cell.special_gem_id:
			definition = candidate
	if special_gem_manager.requirements_met(
		definition, group.color_id, group.size, skill_manager.get_energy(_player_actor_id())
	):
		return SpecialGemGlyph.Status.READY
	return SpecialGemGlyph.Status.BLOCKED

func _on_gem_presentation_event(event_name: String, _payload: Dictionary) -> void:
	if event_name == "skill_energy_changed":
		_refresh_board_views()

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

func _apply_player_cascade_effects(
	cascade_result: CascadeManager.CascadeResult,
	special_effects: Array = []
) -> void:
	if cascade_result == null or cascade_result.match_count <= 0 or enemy_controller == null:
		return

	enemy_controller.prepare_combat()
	var critical_multiplier: float = 1.0
	for special_effect in special_effects:
		if str(special_effect.get("effect_type", "")) == "critical_chance":
			critical_multiplier *= float(
				special_effect.get("effect_parameters", {}).get("critical_multiplier", 2.0)
			)

	_apply_special_gem_effects(special_effects)
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
			cascade_result.combo_multiplier * (critical_multiplier if color_id == "red" else 1.0),
			_special_gem_ids_for_type(special_effects, "critical_chance") if color_id == "red" else []
		)
		enemy_controller.apply_attack_event(attack_event)
		battle_manager.register_outcome(enemy_controller.player_state.current_hp, enemy_controller.enemy_state.current_hp)
		if battle_manager.current_state == BattleManager.BattleState.VICTORY:
			return

func _special_gem_ids_for_type(effects: Array, effect_type: String) -> Array:
	var gem_ids: Array = []
	for effect in effects:
		if str(effect.get("effect_type", "")) == effect_type:
			gem_ids.append(str(effect.get("gem_id", "")))
	return gem_ids

func _apply_special_gem_effects(effects: Array) -> void:
	for effect in effects:
		var gem_id: String = str(effect.get("gem_id", ""))
		var effect_type: String = str(effect.get("effect_type", ""))
		var parameters: Dictionary = effect.get("effect_parameters", {})
		var effect_amount: int = 0
		match effect_type:
			"critical_chance":
				if event_bus != null:
					event_bus.emit("special_gem_activated", {
						"actor_id": _player_actor_id(),
						"gem_id": gem_id,
						"effect_type": effect_type,
						"multiplier": float(parameters.get("critical_multiplier", 2.0)),
					})
				continue
			"fireball":
				if enemy_controller == null or battle_manager == null:
					continue
				effect_amount = max(0, int(parameters.get("damage", 0)))
				var fireball_event: CombatManager.AttackEvent = combat_manager.create_attack_event(
					_player_actor_id(),
					enemy_controller.enemy_state.actor_id,
					"red",
					effect_amount,
					0,
					1.0,
					[gem_id]
				)
				enemy_controller.apply_attack_event(fireball_event)
				battle_manager.register_outcome(
					enemy_controller.player_state.current_hp,
					enemy_controller.enemy_state.current_hp
				)
			"barrier":
				if enemy_controller == null:
					continue
				effect_amount = max(0, int(parameters.get("guard", 0)))
				enemy_controller.combat_manager.grant_guard(_player_actor_id(), effect_amount)
			_:
				push_error("Unsupported special gem effect type '%s' for gem '%s'." % [effect_type, gem_id])
				continue

		if event_bus != null:
			event_bus.emit("special_gem_activated", {
				"actor_id": _player_actor_id(),
				"gem_id": gem_id,
				"effect_type": effect_type,
				"amount": effect_amount,
			})

func _spawn_piece() -> bool:
	if board_manager == null or battle_manager == null:
		return false

	var spawn_position := Vector2i(1, 0)
	active_piece = piece_spawner.create_random_piece(
		battle_manager.player_character.available_colors,
		spawn_position,
		[Vector2i.ZERO, Vector2i.RIGHT],
		battle_manager.player_character.special_gem_loadout
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
			"actor_id": _player_actor_id(),
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

func try_resolve_prepared_group(cell: Vector2i) -> bool:
	if board_manager == null:
		return false
	if not board_manager.is_within_bounds(cell):
		return false

	var group: MatchManager.PreparedGroup = board_manager.find_prepared_group_for_cell(board_manager.prepared_groups, cell)
	if group == null:
		return false

	var loadout: SpecialGemLoadout = null
	if battle_manager != null and battle_manager.player_character != null:
		loadout = battle_manager.player_character.special_gem_loadout
	var equipped_gems: Array[SpecialGemDefinition] = []
	if loadout != null:
		equipped_gems = loadout.get_equipped_gems()
	var gem_result: Dictionary = special_gem_manager.evaluate_group(
		group.special_gems,
		group.color_id,
		group.size,
		equipped_gems,
		skill_manager.get_energy(_player_actor_id())
	)
	var preserved_cells: Array = []
	for inactive_gem in gem_result.get("inactive_gems", []):
		if not bool(inactive_gem.get("remove_when_inactive", true)):
			preserved_cells.append(inactive_gem.get("cell_position", Vector2i(-1, -1)))

	var color_id: String = group.color_id
	var group_size: int = group.size
	var expected_removed_count: int = group_size - preserved_cells.size()
	var special_effects: Array = gem_result.get("effects", [])
	var prepared_result: CascadeManager.CascadeResult = CascadeManager.CascadeResult.new(
		1,
		1,
		expected_removed_count,
		expected_removed_count,
		1.0,
		[],
		{color_id: group_size}
	)
	var energy_spent: int = int(gem_result.get("energy_spent", 0))
	if energy_spent > 0 and not skill_manager.spend_energy(_player_actor_id(), energy_spent):
		push_error("Special gem energy changed before the prepared group could be resolved.")
		return false

	var board_view: BoardView = get_node_or_null("PlayerBoardContainer/BoardView") as BoardView
	_apply_player_cascade_effects(prepared_result, special_effects)
	if board_view != null:
		board_view.play_group_explosion(group)

	var result: Dictionary = board_manager.resolve_prepared_group(
		group,
		_player_actor_id(),
		preserved_cells
	)
	if not bool(result.get("resolved", false)):
		push_error("Prepared group became unavailable while resolving its effects.")
		return false

	var removed_count: int = int(result.get("blocks_removed", 0))
	if event_bus != null:
		event_bus.emit("cascade_resolved", {
			"actor_id": _player_actor_id(),
			"cascade_count": 1,
			"match_count": 1,
			"total_blocks_destroyed": removed_count,
			"combo_multiplier": 1.0,
		})
	if board_view != null and board_view.has_method("show_prepared_highlight"):
		board_view.show_prepared_highlight(board_manager.prepared_groups)
	_refresh_board_views()

	if battle_manager != null and battle_manager.current_state == BattleManager.BattleState.VICTORY:
		return true
	if battle_manager != null and battle_manager.current_state != BattleManager.BattleState.ENEMY_ACTION:
		battle_manager.set_state(BattleManager.BattleState.ENEMY_ACTION)
	return true

func try_resolve_prepared_group_at_screen_position(screen_position: Vector2) -> bool:
	var board_view: BoardView = get_node_or_null("PlayerBoardContainer/BoardView") as BoardView
	if board_view == null:
		return false
	if board_manager == null:
		return false
	var group: MatchManager.PreparedGroup = board_view.find_prepared_group_at_screen_position(
		screen_position,
		board_manager.prepared_groups
	)
	if group == null or group.cells.is_empty():
		return false
	return try_resolve_prepared_group(group.cells[0])

func try_rotate(clockwise: bool = true) -> bool:
	if active_piece == null:
		return false

	if battle_manager != null and not (battle_manager.can_player_act() or battle_manager.can_enemy_act()):
		return false

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

	if event_bus != null:
		event_bus.emit("piece_rotated", {
			"actor_id": _player_actor_id(),
			"piece_id": active_piece.id,
			"orientation": active_piece.orientation,
		})
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
			"actor_id": _player_actor_id(),
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
	var cascade_result: CascadeManager.CascadeResult = await board_manager.resolve_cascade_animated_result(
		_player_actor_id()
	)
	if board_view != null:
		board_view.show_prepared_highlight(board_manager.prepared_groups)
	_refresh_board_views()
	if battle_manager != null and battle_manager.current_state == BattleManager.BattleState.VICTORY:
		return true
	if battle_manager != null and battle_manager.current_state != BattleManager.BattleState.ENEMY_ACTION:
		battle_manager.set_state(BattleManager.BattleState.ENEMY_ACTION)
		return true

	return true
