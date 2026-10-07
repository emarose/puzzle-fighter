extends CanvasLayer

@onready var state_label: Label = $MarginContainer/VBoxContainer/State
@onready var enemy_action_label: Label = $MarginContainer/VBoxContainer/EnemyAction
@onready var player_action_label: Label = $MarginContainer/VBoxContainer/PlayerAction
@onready var enemy_summary_label: Label = $MarginContainer/VBoxContainer/EnemySummary
@onready var chain_summary_label: Label = $MarginContainer/VBoxContainer/ChainSummary
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/Feedback
@onready var turn_label: Label = $MarginContainer/VBoxContainer/Turn
@onready var skill_buttons_container: HBoxContainer = $MarginContainer/VBoxContainer/SkillButtons
@onready var battle_overlay: BattleOverlay = $BattleOverlay

var skill_buttons: Dictionary = {}
var feedback_history: PackedStringArray = []
var battle_result_shown: bool = false
var battle_pause_active: bool = false

var battle_manager: Node
var enemy_controller: Node
var battle_controller: Node
var input_controller: Node
var player_status_panel: ActorStatusPanel
var enemy_status_panel: ActorStatusPanel
var event_bus: EventBus

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	event_bus = EventBus.get_instance()
	if get_parent() != null:
		battle_manager = get_parent().get_node_or_null("BattleManager")
		enemy_controller = get_parent().get_node_or_null("EnemyController")
		battle_controller = get_parent()
		input_controller = get_parent().get_node_or_null("InputController")
		player_status_panel = get_parent().get_node_or_null(
			"PlayerBoardContainer/ActorStatusPanel"
		) as ActorStatusPanel
		enemy_status_panel = get_parent().get_node_or_null(
			"EnemyBoardContainer/ActorStatusPanel"
		) as ActorStatusPanel

	if battle_manager != null and battle_manager.has_signal("state_changed"):
		battle_manager.state_changed.connect(_on_state_changed)
	if event_bus != null:
		event_bus.event_emitted.connect(_on_event_emitted)
	if input_controller != null and input_controller.has_signal("pause_requested"):
		input_controller.pause_requested.connect(_on_pause_requested)
	if battle_overlay != null:
		battle_overlay.resume_requested.connect(_on_resume_requested)

	call_deferred("_build_skill_buttons")
	_update_hud()
	_update_state_summary()

func _exit_tree() -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
		battle_pause_active = false

func _on_state_changed(_old_state: int, _new_state: int) -> void:
	_update_hud()
	_update_state_summary()

func _on_skill_button_pressed(skill_id: String) -> void:
	if battle_controller == null or not battle_controller.has_method("use_skill"):
		return
	if not battle_controller.use_skill(skill_id):
		return
	_update_hud()

func _build_skill_buttons() -> void:
	if battle_controller == null or not battle_controller.has_method("get_player_skill_definitions"):
		return
	skill_buttons.clear()
	for child in skill_buttons_container.get_children():
		child.queue_free()
	var skill_definitions: Array[SkillDefinition] = battle_controller.get_player_skill_definitions()
	for index in range(skill_definitions.size()):
		var definition: SkillDefinition = skill_definitions[index]
		var button := Button.new()
		button.custom_minimum_size.y = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shortcut: String = " [%d]" % (index + 1) if index < 3 else ""
		button.text = "%s (%d)%s" % [definition.name, definition.cost, shortcut]
		button.tooltip_text = definition.description
		button.pressed.connect(_on_skill_button_pressed.bind(definition.id))
		skill_buttons_container.add_child(button)
		skill_buttons[definition.id] = button
	_update_skill_buttons()

func _on_event_emitted(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"battle_state_changed":
			_update_hud()
			_update_state_summary()
		"hp_changed":
			_update_hp_from_event(payload)
		"piece_spawned":
			var actor_id: String = str(payload.get("actor_id", "player"))
			_set_action_summary(actor_id, "Piece spawned", "A new turn is ready", "Place or rotate it")
			_append_feedback("%s has a new piece to place." % _actor_name(actor_id))
		"piece_locked":
			var actor_id: String = str(payload.get("actor_id", "player"))
			_set_action_summary(actor_id, "Piece locked", "Placement is fixed", "Checking for matches")
			_append_feedback("%s locked a piece; the board is checking for matches." % _actor_name(actor_id))
		"piece_moved":
			var actor_id: String = str(payload.get("actor_id", "player"))
			var position: Vector2i = payload.get("position", Vector2i.ZERO)
			_set_action_summary(
				actor_id,
				"Moved piece to column %d, row %d" % [position.x + 1, position.y + 1],
				"Adjusting the piece placement",
				"Piece remains active"
			)
		"piece_rotated":
			var actor_id: String = str(payload.get("actor_id", ""))
			_set_action_summary(
				actor_id,
				"Rotated active piece",
				"Changing its block alignment",
				"Piece remains active"
			)
		"cascade_started":
			chain_summary_label.text = "Combo: 0 groups | Cascades: 0 waves"
			var actor_id: String = str(payload.get("actor_id", ""))
			_set_action_summary(actor_id, "Resolving board", "Checking connected colors", "Matches may clear")
		"match_found":
			var actor_id: String = str(payload.get("actor_id", ""))
			var colors: String = _format_colors(payload.get("colors", []))
			var groups: int = int(payload.get("match_count", 0))
			var blocks: int = int(payload.get("total_blocks", 0))
			var reason: String = "Connected matching colors: %s" % colors if not colors.is_empty() else "Connected matching colors"
			_set_action_summary(
				actor_id,
				"Matched %d blocks in %d groups" % [blocks, groups],
				reason,
				"Clearing blocks and checking cascades"
			)
			_append_feedback(
				"%s matched %d blocks in %d groups (%s); those blocks are clearing." % [
					_actor_name(actor_id),
					blocks,
					groups,
					colors if not colors.is_empty() else "colors",
				]
			)
		"match_destroyed":
			var actor_id: String = str(payload.get("actor_id", ""))
			_set_action_summary(
				actor_id,
				"Cleared %d blocks" % int(payload.get("total_blocks", 0)),
				"Matched groups were removed",
				"Gravity can create another cascade"
			)
		"cascade_finished":
			_update_chain_summary(payload)
			_summarize_cascade(payload)
		"cascade_resolved":
			_update_chain_summary(payload)
		"skill_energy_changed":
			_update_hud()
		"skill_used":
			_update_hud()
			var actor_id: String = str(payload.get("actor_id", ""))
			var target_id: String = str(payload.get("target_actor", ""))
			var amount: int = int(payload.get("amount", 0))
			var target_text: String = " on %s" % _actor_name(target_id) if not target_id.is_empty() else ""
			_set_action_summary(
				actor_id,
				"Used %s" % str(payload.get("skill_id", "")).replace("_", " ").capitalize(),
				"%s skill effect activated" % str(payload.get("effect_type", "unknown")),
				"Effect amount: %d%s" % [amount, target_text]
			)
			_append_feedback(
				"%s used %s%s; effect amount: %d." % [
					_actor_name(actor_id),
					str(payload.get("skill_id", "")).replace("_", " "),
					target_text,
					amount,
				]
			)
		"attack_created":
			_summarize_attack(payload)
		"damage_received":
			var actor_id: String = str(payload.get("actor_id", ""))
			var actor_name: String = _actor_name(actor_id)
			var absorbed_amount: int = int(payload.get("absorbed_amount", 0))
			var damage: int = int(payload.get("amount", 0))
			var remaining_hp: int = int(payload.get("current_hp", 0))
			var reason: String = "Guard blocked %d incoming damage" % absorbed_amount if absorbed_amount > 0 else "Guard did not absorb the attack"
			var consequence: String = "%d HP lost; %d HP remains" % [damage, remaining_hp]
			_set_action_summary(actor_id, "Took %d HP damage" % damage, reason, consequence)
			_append_feedback(
				"%s took %d HP damage; %s, leaving %d HP." % [
					actor_name,
					damage,
					"guard absorbed %d" % absorbed_amount if absorbed_amount > 0 else "no damage was blocked",
					remaining_hp,
				]
			)
		"guard_applied":
			_update_hud()
			var actor_id: String = str(payload.get("actor_id", ""))
			var amount: int = int(payload.get("amount", 0))
			var total_guard: int = int(payload.get("total_guard", amount))
			_set_action_summary(actor_id, "Gained %d Guard" % amount, "A defensive effect resolved", "%d Guard available" % total_guard)
			_append_feedback("%s gained %d Guard; %d is now available." % [
				_actor_name(actor_id),
				amount,
				total_guard,
			])
		"guard_absorbed":
			_update_hud()
			var actor_id: String = str(payload.get("actor_id", ""))
			_set_action_summary(
				actor_id,
				"Blocked %d damage" % int(payload.get("amount", 0)),
				"Guard absorbed incoming damage",
				"%d Guard remains" % int(payload.get("remaining_guard", 0))
			)
		"enemy_action_started":
			var turn: int = int(payload.get("turn", 0)) + 1
			enemy_action_label.text = "Enemy intent: resolving turn %d" % turn
			enemy_summary_label.text = "Enemy action: turn %d is resolving." % turn
			_set_action_summary("enemy", "Started turn %d" % turn, "Player resolution finished", "Enemy is acting")
			_append_feedback("Enemy turn %d started; the enemy is choosing and resolving a move." % turn)
		"enemy_action_finished":
			_update_hud()
			_update_state_summary()
			var turn: int = int(payload.get("turn", 0)) + 1
			var success: bool = bool(payload.get("success", false))
			var result: String = "Turn resolved" if success else "Turn could not be completed"
			enemy_action_label.text = "Enemy intent: %s" % result.to_lower()
			enemy_summary_label.text = "Enemy action: %s." % result
			_set_action_summary("enemy", result, "Enemy action sequence ended", "Player turn is ready")
			_append_feedback("Enemy turn %d ended: %s." % [turn, result.to_lower()])

func _set_action_summary(actor_id: String, what: String, why: String, consequence: String) -> void:
	var summary: String = "%s: %s\nWHY: %s\nRESULT: %s" % [
		_actor_name(actor_id),
		what,
		why,
		consequence,
	]
	if _is_player_actor(actor_id):
		player_action_label.text = summary
	else:
		enemy_summary_label.text = summary

func _actor_name(actor_id: String) -> String:
	if enemy_controller != null:
		if actor_id == enemy_controller.player_state.actor_id:
			return _get_player_name()
		if actor_id == enemy_controller.enemy_state.actor_id:
			return _get_enemy_name()
	return actor_id.capitalize() if not actor_id.is_empty() else "Battle"

func _is_player_actor(actor_id: String) -> bool:
	return actor_id == "player" or (
		enemy_controller != null and actor_id == enemy_controller.player_state.actor_id
	)

func _format_colors(colors: Array) -> String:
	var labels: PackedStringArray = []
	for color_id in colors:
		labels.append(str(color_id).capitalize())
	return ", ".join(labels)

func _append_feedback(message: String) -> void:
	feedback_history.append(message)
	while feedback_history.size() > 2:
		feedback_history.remove_at(0)
	feedback_label.text = "Battle feedback:\n" + "\n".join(feedback_history)

func _update_chain_summary(payload: Dictionary) -> void:
	var combo_count: int = int(payload.get("match_count", 0))
	var cascade_count: int = int(payload.get("cascade_count", 0))
	var multiplier: float = float(payload.get("combo_multiplier", 1.0))
	chain_summary_label.text = "Combo: %d groups | Cascades: %d waves | Multiplier: x%.1f" % [
		combo_count,
		cascade_count,
		multiplier if cascade_count > 0 else 1.0,
	]

func _summarize_cascade(payload: Dictionary) -> void:
	var actor_id: String = str(payload.get("actor_id", ""))
	var matches: int = int(payload.get("match_count", 0))
	var cascades: int = int(payload.get("cascade_count", 0))
	var blocks: int = int(payload.get("total_blocks", 0))
	if cascades <= 0:
		_set_action_summary(actor_id, "No match", "No connected group met the clear rule", "Board stays unchanged")
		_append_feedback("%s found no matches; the board remains unchanged." % _actor_name(actor_id))
		return
	var multiplier: float = float(payload.get("combo_multiplier", 1.0))
	var attack_power: int = int(payload.get("attack_power", 0))
	var consequence: String = "%d blocks cleared; attack power %d" % [blocks, attack_power]
	_set_action_summary(
		actor_id,
		"Built a %d-wave cascade" % cascades,
		"%d match groups chained at x%.1f" % [matches, multiplier],
		consequence
	)
	_append_feedback(
		"%s chained %d match groups across %d cascade waves (x%.1f); %d blocks cleared and attack power %d generated." % [
			_actor_name(actor_id),
			matches,
			cascades,
			multiplier,
			blocks,
			attack_power,
		]
	)

func _summarize_attack(payload: Dictionary) -> void:
	var source_id: String = str(payload.get("source", ""))
	var target_id: String = str(payload.get("target", ""))
	var source_name: String = _actor_name(source_id)
	var target_name: String = _actor_name(target_id)
	var color: String = str(payload.get("color", "")).capitalize()
	var amount: int = int(payload.get("amount", 0))
	var role: String = str(payload.get("role", "DAMAGE")).to_lower()
	var multiplier: float = float(payload.get("combo_multiplier", 1.0))
	var cascade_bonus: int = int(payload.get("cascade_bonus", 0))
	var reason: String = "%s match; combo multiplier x%.1f" % [color, multiplier]
	if cascade_bonus > 0:
		reason += " and +%d cascade bonus" % cascade_bonus
	var consequence: String
	match role:
		"damage":
			consequence = "%s receives %d attack power" % [target_name, amount]
		"defense":
			consequence = "%s gains %d Guard" % [source_name, amount]
		"heal":
			consequence = "%s restores up to %d HP" % [source_name, amount]
		"energy":
			consequence = "%s gains %d Energy" % [source_name, amount]
		_:
			consequence = "%s effect: %d" % [source_name, amount]
	_set_action_summary(source_id, "Resolved %s effect (%s: %d)" % [role.capitalize(), color, amount], reason, consequence)
	_append_feedback("%s matched %s; %s." % [source_name, color, consequence.to_lower()])

func _on_pause_requested() -> void:
	if battle_manager == null or get_tree() == null:
		return
	if battle_manager.current_state in [
		BattleManager.BattleState.VICTORY,
		BattleManager.BattleState.DEFEAT,
	]:
		return
	if battle_pause_active:
		_on_resume_requested()
		return
	battle_overlay.show_pause()
	state_label.text = "State: PAUSED"
	battle_pause_active = true
	get_tree().paused = true

func _on_resume_requested() -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
	battle_pause_active = false
	battle_overlay.hide_overlay()
	_update_state_summary()

func _show_battle_result(is_victory: bool) -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
		battle_pause_active = false
	if battle_result_shown:
		return
	battle_result_shown = true
	battle_overlay.show_result(is_victory)
	if is_victory:
		_append_feedback("Victory: the enemy HP reached zero.")
	else:
		_append_feedback("Defeat: player HP reached zero.")

func _update_state_summary() -> void:
	if battle_manager == null:
		state_label.text = "State: UNKNOWN"
		return

	var state_name: String = _battle_state_name(battle_manager.current_state)
	var summary: String = "Player turn"
	match battle_manager.current_state:
		BattleManager.BattleState.PLAYING:
			summary = "Player turn"
		BattleManager.BattleState.PIECE_ACTIVE:
			summary = "Piece active"
		BattleManager.BattleState.RESOLVING:
			summary = "Resolving match"
		BattleManager.BattleState.ENEMY_ACTION:
			summary = "Enemy turn"
		BattleManager.BattleState.PLAYER_DEFEATED:
			summary = "Player defeated"
		BattleManager.BattleState.ENEMY_DEFEATED:
			summary = "Enemy defeated"
		BattleManager.BattleState.VICTORY:
			summary = "Victory"
		BattleManager.BattleState.DEFEAT:
			summary = "Defeat"
		_:
			summary = "Battle status"
	state_label.text = "State: %s (%s)" % [state_name, summary]
	if battle_manager.current_state == BattleManager.BattleState.VICTORY:
		_show_battle_result(true)
	elif battle_manager.current_state == BattleManager.BattleState.DEFEAT:
		_show_battle_result(false)

func _battle_state_name(_state: int) -> String:
	if battle_manager != null and battle_manager.current_state >= 0 and battle_manager.current_state < BattleManager.BattleState.keys().size():
		return BattleManager.BattleState.keys()[battle_manager.current_state]
	return "UNKNOWN"

func _update_hp_from_event(payload: Dictionary) -> void:
	var player_actor_id: String = "player"
	var enemy_actor_id: String = "enemy"
	if enemy_controller != null:
		player_actor_id = enemy_controller.player_state.actor_id
		enemy_actor_id = enemy_controller.enemy_state.actor_id
	if payload.get("actor_id", "") == player_actor_id:
		var player_max_hp: int = enemy_controller.player_state.max_hp if enemy_controller != null else 0
		if player_status_panel != null:
			player_status_panel.update_hp(int(payload.get("current_hp", 0)), player_max_hp)
	elif payload.get("actor_id", "") == enemy_actor_id:
		var enemy_max_hp: int = enemy_controller.enemy_state.max_hp if enemy_controller != null else 0
		if enemy_status_panel != null:
			enemy_status_panel.update_hp(int(payload.get("current_hp", 0)), enemy_max_hp)

func _update_hud() -> void:
	if battle_manager != null:
		var state_name: String = _battle_state_name(battle_manager.current_state)
		state_label.text = "State: %s" % state_name

	if enemy_controller != null and enemy_controller.has_method("get_current_attack_preview"):
		enemy_action_label.text = "Enemy intent: %s" % enemy_controller.get_current_attack_preview()
	else:
		enemy_action_label.text = "Enemy intent: idle"

	if enemy_controller != null and enemy_controller.has_method("get_current_attack_preview"):
		turn_label.text = "Turn: %d" % enemy_controller.turn_counter
	else:
		turn_label.text = "Turn: 0"

	if player_status_panel != null and enemy_controller != null and enemy_controller.get("player_state") != null:
		var player_state: CombatState = enemy_controller.get("player_state")
		player_status_panel.update_status(
			_get_player_name(),
			player_state.current_hp,
			player_state.max_hp,
			battle_controller.get_player_guard(),
			battle_controller.get_skill_energy(),
			battle_controller.get_max_energy()
		)
	if enemy_status_panel != null and enemy_controller != null and enemy_controller.get("enemy_state") != null:
		var enemy_state: CombatState = enemy_controller.get("enemy_state")
		enemy_status_panel.update_status(
			_get_enemy_name(),
			enemy_state.current_hp,
			enemy_state.max_hp,
			battle_controller.get_enemy_guard(),
			battle_controller.get_enemy_energy(),
			battle_controller.get_max_energy()
		)
	_update_skill_buttons()

func _get_player_name() -> String:
	if battle_manager != null and battle_manager.player_character != null:
		return battle_manager.player_character.name
	return "Player"

func _get_enemy_name() -> String:
	if battle_manager != null and battle_manager.enemy_character != null:
		return battle_manager.enemy_character.name
	return "Enemy"

func _update_skill_buttons() -> void:
	if battle_controller == null:
		for button in skill_buttons.values():
			button.disabled = true
		return
	if not battle_controller.has_method("can_use_skill"):
		for button in skill_buttons.values():
			button.disabled = true
		return
	for skill_id in skill_buttons:
		var button: Button = skill_buttons[skill_id]
		button.disabled = not battle_controller.can_use_skill(skill_id)
