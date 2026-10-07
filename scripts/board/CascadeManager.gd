class_name CascadeManager
extends RefCounted

var event_bus: EventBus

func _init() -> void:
	event_bus = EventBus.get_instance()

class CascadeResult:
	extends RefCounted

	var cascade_count: int = 0
	var match_count: int = 0
	var total_blocks_destroyed: int = 0
	var attack_power: int = 0
	var combo_multiplier: float = 1.0
	var color_block_counts: Dictionary = {}
	var rounds: Array = []

	func _init(p_cascade_count: int = 0, p_match_count: int = 0, p_total_blocks_destroyed: int = 0, p_attack_power: int = 0, p_combo_multiplier: float = 1.0, p_rounds: Array = [], p_color_block_counts: Dictionary = {}) -> void:
		cascade_count = p_cascade_count
		match_count = p_match_count
		total_blocks_destroyed = p_total_blocks_destroyed
		attack_power = p_attack_power
		combo_multiplier = p_combo_multiplier
		rounds = p_rounds
		color_block_counts = p_color_block_counts

func resolve(board: BoardManager, match_manager: MatchManager = null, actor_id: String = "", combat_tuning: CombatTuning = null) -> CascadeResult:
	if board == null:
		return CascadeResult.new(0, 0, 0, 0, 1.0, [])

	var active_tuning: CombatTuning = _get_active_tuning(combat_tuning)
	var active_match_manager: MatchManager = match_manager if match_manager != null else MatchManager.new()
	var state: Dictionary = _begin_resolution(actor_id)

	while true:
		var match_result: MatchManager.MatchResult = _find_match_result(
			board,
			active_match_manager,
			actor_id
		)
		if match_result == null:
			break

		_record_match_round(state, board, match_result)
		_destroy_match_round(board, match_result, actor_id)

	return _finish_resolution(state, active_tuning, actor_id)

func resolve_animated(
	board: BoardManager,
	match_manager: MatchManager = null,
	actor_id: String = "",
	combat_tuning: CombatTuning = null,
	before_destroy: Callable = Callable()
) -> CascadeResult:
	if board == null:
		return CascadeResult.new(0, 0, 0, 0, 1.0, [])

	var active_tuning: CombatTuning = _get_active_tuning(combat_tuning)
	var active_match_manager: MatchManager = match_manager if match_manager != null else MatchManager.new()
	var state: Dictionary = _begin_resolution(actor_id)

	while true:
		var match_result: MatchManager.MatchResult = _find_match_result(
			board,
			active_match_manager,
			actor_id
		)
		if match_result == null:
			break

		_record_match_round(state, board, match_result)
		if before_destroy.is_valid():
			await before_destroy.call(match_result.groups)
		_destroy_match_round(board, match_result, actor_id)

	return _finish_resolution(state, active_tuning, actor_id)

func _get_active_tuning(combat_tuning: CombatTuning) -> CombatTuning:
	if combat_tuning != null:
		return combat_tuning
	return preload("res://resources/combat_tuning.tres")

func _begin_resolution(actor_id: String) -> Dictionary:
	if event_bus != null:
		event_bus.emit("cascade_started", {"actor_id": actor_id})
	return {
		"rounds": [],
		"cascade_count": 0,
		"match_count": 0,
		"total_blocks_destroyed": 0,
		"color_block_counts": {},
	}

func _find_match_result(
	board: BoardManager,
	match_manager: MatchManager,
	actor_id: String
) -> MatchManager.MatchResult:
	var match_result: MatchManager.MatchResult = match_manager.detect_matches(board)
	if match_result.match_count <= 0:
		return null
	if event_bus != null:
		event_bus.emit("match_found", {
			"actor_id": actor_id,
			"match_count": match_result.match_count,
			"total_blocks": match_result.total_blocks_destroyed,
			"colors": match_result.affected_colors,
		})
	return match_result

func _record_match_round(
	state: Dictionary,
	board: BoardManager,
	match_result: MatchManager.MatchResult
) -> void:
	state["cascade_count"] = int(state["cascade_count"]) + 1
	state["match_count"] = int(state["match_count"]) + match_result.match_count
	state["total_blocks_destroyed"] = (
		int(state["total_blocks_destroyed"]) + match_result.total_blocks_destroyed
	)
	var rounds: Array = state["rounds"]
	rounds.append(match_result)
	var color_block_counts: Dictionary = state["color_block_counts"]
	for group in match_result.groups:
		if group.is_empty():
			continue
		var matched_cell: BoardCell = board.get_cell(group[0])
		if matched_cell.is_empty:
			continue
		color_block_counts[matched_cell.color_id] = (
			int(color_block_counts.get(matched_cell.color_id, 0)) + group.size()
		)

func _destroy_match_round(
	board: BoardManager,
	match_result: MatchManager.MatchResult,
	actor_id: String
) -> void:
	for group in match_result.groups:
		for cell_position in group:
			board.clear_cell(cell_position)
	if event_bus != null:
		event_bus.emit("match_destroyed", {
			"actor_id": actor_id,
			"total_blocks": match_result.total_blocks_destroyed,
			"colors": match_result.affected_colors,
		})
	board.apply_gravity()

func _finish_resolution(
	state: Dictionary,
	active_tuning: CombatTuning,
	actor_id: String
) -> CascadeResult:
	var cascade_count: int = int(state["cascade_count"])
	var total_blocks_destroyed: int = int(state["total_blocks_destroyed"])
	var combo_multiplier: float = (
		1.0 + (cascade_count - 1) * active_tuning.combo_step_per_extra_wave
	)
	var attack_power: int = int(total_blocks_destroyed * combo_multiplier)
	var result := CascadeResult.new(
		cascade_count,
		int(state["match_count"]),
		total_blocks_destroyed,
		attack_power,
		combo_multiplier,
		state["rounds"],
		state["color_block_counts"]
	)
	if event_bus != null:
		event_bus.emit("cascade_finished", {
			"actor_id": actor_id,
			"cascade_count": cascade_count,
			"match_count": result.match_count,
			"total_blocks": total_blocks_destroyed,
			"attack_power": attack_power,
			"combo_multiplier": combo_multiplier,
		})
	return result
