class_name CascadeManager
extends RefCounted

class CascadeResult:
	extends RefCounted

	var cascade_count: int = 0
	var match_count: int = 0
	var total_blocks_destroyed: int = 0
	var attack_power: int = 0
	var combo_multiplier: float = 1.0
	var rounds: Array = []

	func _init(p_cascade_count: int = 0, p_match_count: int = 0, p_total_blocks_destroyed: int = 0, p_attack_power: int = 0, p_combo_multiplier: float = 1.0, p_rounds: Array = []) -> void:
		cascade_count = p_cascade_count
		match_count = p_match_count
		total_blocks_destroyed = p_total_blocks_destroyed
		attack_power = p_attack_power
		combo_multiplier = p_combo_multiplier
		rounds = p_rounds

func resolve(board: BoardManager, match_manager: MatchManager = null) -> CascadeResult:
	if board == null:
		return CascadeResult.new(0, 0, 0, 0, 1.0, [])

	var active_match_manager: MatchManager = match_manager if match_manager != null else MatchManager.new()
	var rounds: Array = []
	var cascade_count: int = 0
	var total_match_count: int = 0
	var total_blocks_destroyed: int = 0

	while true:
		var match_result: MatchManager.MatchResult = active_match_manager.detect_matches(board)
		if match_result.match_count <= 0:
			break

		cascade_count += 1
		total_match_count += match_result.match_count
		total_blocks_destroyed += match_result.total_blocks_destroyed
		rounds.append(match_result)

		for group in match_result.groups:
			for cell_position in group:
				board.clear_cell(cell_position)

		board.apply_gravity()

	var combo_multiplier: float = 1.0 + (cascade_count - 1) * 0.5
	var attack_power: int = int(total_blocks_destroyed * combo_multiplier)
	return CascadeResult.new(cascade_count, total_match_count, total_blocks_destroyed, attack_power, combo_multiplier, rounds)
