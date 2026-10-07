extends CanvasLayer

@onready var state_label: Label = $MarginContainer/VBoxContainer/State
@onready var enemy_action_label: Label = $MarginContainer/VBoxContainer/EnemyAction
@onready var turn_label: Label = $MarginContainer/VBoxContainer/Turn
@onready var skill_buttons_container: HBoxContainer = $MarginContainer/VBoxContainer/SkillButtons

var skill_buttons: Dictionary = {}

var battle_manager: Node
var enemy_controller: Node
var battle_controller: Node
var player_status_panel: ActorStatusPanel
var enemy_status_panel: ActorStatusPanel
var event_bus: EventBus

func _ready() -> void:
	event_bus = EventBus.get_instance()
	if get_parent() != null:
		battle_manager = get_parent().get_node_or_null("BattleManager")
		enemy_controller = get_parent().get_node_or_null("EnemyController")
		battle_controller = get_parent()
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

	call_deferred("_build_skill_buttons")
	_update_hud()

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
			enemy_action_label.text = "Enemy intent: piece spawned"
		"piece_locked":
			enemy_action_label.text = "Enemy intent: piece locked"
		"cascade_resolved":
			enemy_action_label.text = "Enemy intent: cascade %d" % int(payload.get("cascade_count", 0))
		"skill_energy_changed":
			_update_hud()
			if enemy_controller != null and str(payload.get("actor_id", "")) == enemy_controller.player_state.actor_id:
				enemy_action_label.text = "Player energy: %d / %d" % [
					int(payload.get("energy", 0)),
					battle_controller.get_max_energy(),
				]
		"skill_used":
			_update_hud()
			enemy_action_label.text = "Skill used: %s" % str(payload.get("skill_id", ""))
		"attack_created":
			enemy_action_label.text = "%s matched %s: %d" % [str(payload.get("source", "")).capitalize(), str(payload.get("color", "")).capitalize(), int(payload.get("amount", 0))]
		"match_found":
			var matched_colors: PackedStringArray = []
			for color_id in payload.get("colors", []):
				matched_colors.append(str(color_id))
			enemy_action_label.text = "Match: %d blocks (%s)" % [int(payload.get("total_blocks", 0)), ", ".join(matched_colors)]
		"damage_received":
			var actor_name: String = str(payload.get("actor_id", "")).capitalize()
			var absorbed_amount: int = int(payload.get("absorbed_amount", 0))
			if absorbed_amount > 0:
				enemy_action_label.text = "%s took %d damage; guard blocked %d" % [
					actor_name,
					int(payload.get("amount", 0)),
					absorbed_amount,
				]
			else:
				enemy_action_label.text = "%s took %d damage" % [actor_name, int(payload.get("amount", 0))]
		"guard_applied":
			_update_hud()
			enemy_action_label.text = "%s gained %d guard" % [str(payload.get("actor_id", "")).capitalize(), int(payload.get("amount", 0))]
		"guard_absorbed":
			_update_hud()
			enemy_action_label.text = "%s blocked %d damage" % [str(payload.get("actor_id", "")).capitalize(), int(payload.get("amount", 0))]
		"enemy_action_started":
			enemy_action_label.text = "Enemy turn: resolving"
		"enemy_action_finished":
			_update_hud()
			_update_state_summary()

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
		BattleManager.BattleState.VICTORY:
			summary = "Victory"
		BattleManager.BattleState.DEFEAT:
			summary = "Defeat"
		_:
			summary = "Battle status"
	state_label.text = "State: %s (%s)" % [state_name, summary]

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
