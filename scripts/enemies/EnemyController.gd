class_name EnemyController
extends Node

var battle_manager: Node
var battle_controller: Node
var combat_manager: CombatManager = CombatManager.new()
var player_state: CombatState = CombatState.new("player", 100, 100)
var enemy_state: CombatState = CombatState.new("enemy", 100, 100)
var action_sequence: EnemyActionSequence = EnemyActionSequence.new()
var current_attack_preview: String = "Enemy intent: idle"
var turn_counter: int = 0
var enemy_board_ready: bool = false

func _ready() -> void:
	battle_manager = get_parent().get_node_or_null("BattleManager")
	battle_controller = get_parent()
	enemy_board_ready = battle_controller != null and battle_controller.has_node("EnemyBoardContainer") and battle_controller.get_node_or_null("EnemyBoardContainer/BoardManager") != null
	combat_manager.register_actor(player_state.actor_id, player_state.max_hp, player_state.current_hp)
	combat_manager.register_actor(enemy_state.actor_id, enemy_state.max_hp, enemy_state.current_hp)

func bind_battle_and_controller(p_battle_manager: Node, p_battle_controller: Node) -> void:
	battle_manager = p_battle_manager
	battle_controller = p_battle_controller
	enemy_board_ready = battle_controller != null and battle_controller.has_node("EnemyBoardContainer") and battle_controller.get_node_or_null("EnemyBoardContainer/BoardManager") != null

func is_enemy_ready() -> bool:
	return enemy_board_ready

func get_current_attack_preview() -> String:
	return current_attack_preview

func apply_attack_event(event: CombatManager.AttackEvent) -> bool:
	if event == null:
		return false

	if event.target == "enemy":
		combat_manager.register_actor(enemy_state.actor_id, enemy_state.max_hp, enemy_state.current_hp)
		var enemy_hp_after: int = combat_manager.apply_damage(enemy_state.actor_id, event.amount)
		enemy_state.current_hp = enemy_hp_after
		current_attack_preview = "Enemy intent: %s strike for %d" % [event.color.capitalize(), event.amount]
		return true

	if event.target == "player":
		combat_manager.register_actor(player_state.actor_id, player_state.max_hp, player_state.current_hp)
		var player_hp_after: int = combat_manager.apply_damage(player_state.actor_id, event.amount)
		player_state.current_hp = player_hp_after
		current_attack_preview = "Enemy intent: %s burst for %d" % [event.color.capitalize(), event.amount]
		return true

	return false

func execute_turn() -> bool:
	if battle_controller == null:
		return false
	if not is_enemy_ready():
		if battle_manager != null:
			battle_manager.set_state(BattleManager.BattleState.PLAYING)
		return false

	var actions: Array = action_sequence.get_actions()
	var success: bool = true

	for action in actions:
		var action_name: String = action.get("name", "")
		match action_name:
			"spawn":
				current_attack_preview = "Enemy intent: spawn %s piece" % str(action.get("color", "green"))
				if not battle_controller.has_method("spawn_enemy_piece"):
					success = false
					break
				success = bool(battle_controller.spawn_enemy_piece(action.get("color", "green")))
			"move":
				current_attack_preview = "Enemy intent: move toward player"
				if battle_controller.has_method("enemy_move"):
					success = bool(battle_controller.enemy_move(action.get("direction", Vector2i(0, 1))))
				else:
					success = true
			"rotate":
				current_attack_preview = "Enemy intent: rotate to line up"
				if battle_controller.has_method("enemy_rotate"):
					success = bool(battle_controller.enemy_rotate(action.get("clockwise", true)))
				else:
					success = true
			"lock":
				current_attack_preview = "Enemy intent: lock board"
				if battle_controller.has_method("lock_enemy_piece"):
					success = bool(battle_controller.lock_enemy_piece())
				else:
					success = true
			"resolve":
				current_attack_preview = "Enemy intent: cascade resolve"
				if battle_controller.has_method("resolve_enemy_board"):
					success = bool(battle_controller.resolve_enemy_board())
				else:
					success = true
			"attack":
				var attack_amount: int = int(action.get("amount", 12))
				var color_id: String = str(action.get("color", "green"))
				current_attack_preview = "Enemy intent: %s strike for %d" % [color_id.capitalize(), attack_amount]
				var event: CombatManager.AttackEvent = combat_manager.resolve_attack(
					enemy_state.actor_id,
					player_state.actor_id,
					color_id,
					attack_amount,
					1,
					1.0,
					[]
				)
				player_state.current_hp = combat_manager.get_actor_hp(player_state.actor_id)
				enemy_state.current_hp = combat_manager.get_actor_hp(enemy_state.actor_id)
				if event.amount <= 0:
					success = false
			"wait":
				current_attack_preview = "Enemy intent: recover and wait"
				pass
			_:
				success = false

		if not success:
			break

	turn_counter += 1
	if battle_manager != null:
		battle_manager.register_outcome(player_state.current_hp, enemy_state.current_hp)
		if battle_manager.current_state != BattleManager.BattleState.VICTORY and battle_manager.current_state != BattleManager.BattleState.DEFEAT:
			battle_manager.set_state(BattleManager.BattleState.PLAYING)

	return success
