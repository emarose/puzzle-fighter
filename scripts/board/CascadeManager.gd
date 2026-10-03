class_name CascadeManager
extends RefCounted

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

func resolve(board: BoardManager, match_manager: MatchManager = null) -> CascadeResult:
	if board == null:
		return CascadeResult.new(0, 0, 0, 0, 1.0, [])

	var active_match_manager: MatchManager = match_manager if match_manager != null else MatchManager.new()
	var rounds: Array = []
	var cascade_count: int = 0
	var total_match_count: int = 0
	var total_blocks_destroyed: int = 0
	var color_block_counts: Dictionary = {}

	while true:
		var match_result: MatchManager.MatchResult = active_match_manager.detect_matches(board)
		if match_result.match_count <= 0:
			break

		cascade_count += 1
		total_match_count += match_result.match_count
		total_blocks_destroyed += match_result.total_blocks_destroyed
		rounds.append(match_result)

		for group in match_result.groups:
			if not group.is_empty():
				var matched_cell: BoardCell = board.get_cell(group[0])
				if not matched_cell.is_empty:
					if not color_block_counts.has(matched_cell.color_id):
						color_block_counts[matched_cell.color_id] = 0
					color_block_counts[matched_cell.color_id] += group.size()
			for cell_position in group:
				board.clear_cell(cell_position)

		board.apply_gravity()

	var combo_multiplier: float = 1.0 + (cascade_count - 1) * 0.5
	var attack_power: int = int(total_blocks_destroyed * combo_multiplier)
	return CascadeResult.new(cascade_count, total_match_count, total_blocks_destroyed, attack_power, combo_multiplier, rounds, color_block_counts)
