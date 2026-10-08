extends CanvasLayer

@onready var turn_label: Label = $MarginContainer/VBoxContainer/Turn
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/Feedback
@onready var special_gem_panel: SpecialGemPanel = $MarginContainer/VBoxContainer/SpecialGemPanel
@onready var skill_buttons_container: HBoxContainer = $MarginContainer/VBoxContainer/SkillButtons
@onready var mobile_controls: VBoxContainer = $MarginContainer/VBoxContainer/MobileControls
@onready var battle_overlay: BattleOverlay = $BattleOverlay

var skill_buttons: Dictionary = {}
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
	if input_controller != null:
		_connect_mobile_controls()
		if input_controller.has_signal("pause_requested"):
			input_controller.pause_requested.connect(_on_pause_requested)
	if battle_overlay != null:
		battle_overlay.resume_requested.connect(_on_resume_requested)
		battle_overlay.restart_requested.connect(_on_restart_requested)

	call_deferred("_build_skill_buttons")
	call_deferred("_configure_special_gem_panel")
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
	if input_controller == null or not input_controller.has_method("try_use_skill"):
		return
	if not input_controller.call("try_use_skill", skill_id):
		return
	_update_hud()

func _connect_mobile_controls() -> void:
	var controls: Dictionary = {
		"MovementControls/MoveLeft": "try_move_left",
		"MovementControls/SoftDrop": "try_soft_drop",
		"MovementControls/MoveRight": "try_move_right",
		"ActionControls/Rotate": "try_rotate",
		"ActionControls/HardDrop": "try_hard_drop",
		"ActionControls/Pause": "try_pause",
	}
	for button_path: String in controls:
		var button: Button = mobile_controls.get_node(button_path)
		var method_name: String = controls[button_path]
		if input_controller.has_method(method_name):
			button.pressed.connect(Callable(input_controller, method_name))

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

func _configure_special_gem_panel() -> void:
	if special_gem_panel == null or battle_controller == null:
		return
	if not battle_controller.has_method("get_player_special_gems"):
		return
	special_gem_panel.configure(
		battle_controller.get_player_special_gems(),
		battle_controller.get_skill_energy()
	)

func _on_event_emitted(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"battle_state_changed":
			_update_hud()
			_update_state_summary()
		"hp_changed":
			_update_hp_from_event(payload)
		"skill_energy_changed", "guard_applied", "guard_absorbed":
			_update_hud()
		"cascade_finished":
			var cascades: int = int(payload.get("cascade_count", 0))
			if cascades > 0:
				_set_feedback("%s: %d-wave chain, %d blocks" % [
					_actor_name(str(payload.get("actor_id", ""))),
					cascades,
					int(payload.get("total_blocks", 0)),
				])
		"skill_used":
			_update_hud()
			_set_feedback("%s used %s" % [
				_actor_name(str(payload.get("actor_id", ""))),
				str(payload.get("skill_id", "")).replace("_", " ").capitalize(),
			])
		"special_gem_activated":
			_update_hud()
			_set_feedback("%s activated" % str(payload.get("gem_id", "")).replace("_", " ").capitalize())
		"attack_created":
			_set_feedback("%s: %s %d" % [
				_actor_name(str(payload.get("source", ""))),
				str(payload.get("role", "damage")).capitalize(),
				int(payload.get("amount", 0)),
			])
		"damage_received":
			_set_feedback("%s took %d damage" % [
				_actor_name(str(payload.get("actor_id", ""))),
				int(payload.get("amount", 0)),
			])
		"enemy_action_finished":
			_update_hud()
			_update_state_summary()

func _set_feedback(message: String) -> void:
	feedback_label.text = message

func _actor_name(actor_id: String) -> String:
	if enemy_controller != null:
		if actor_id == enemy_controller.player_state.actor_id:
			return _get_player_name()
		if actor_id == enemy_controller.enemy_state.actor_id:
			return _get_enemy_name()
	return actor_id.capitalize() if not actor_id.is_empty() else "Battle"

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
	battle_pause_active = true
	get_tree().paused = true

func _on_resume_requested() -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
	battle_pause_active = false
	battle_overlay.hide_overlay()
	_update_state_summary()

func _on_restart_requested() -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		push_error("Cannot restart the battle because the scene tree is unavailable.")
		return
	var error: Error = scene_tree.reload_current_scene()
	if error != OK:
		push_error("Failed to restart the battle: %s" % error_string(error))

func _show_battle_result(is_victory: bool) -> void:
	if battle_pause_active and get_tree() != null:
		get_tree().paused = false
		battle_pause_active = false
	if battle_result_shown:
		return
	battle_result_shown = true
	battle_overlay.show_result(is_victory)
	_set_feedback("Victory" if is_victory else "Defeat")

func _update_state_summary() -> void:
	if battle_manager == null:
		return
	if battle_manager.current_state == BattleManager.BattleState.VICTORY:
		_show_battle_result(true)
	elif battle_manager.current_state == BattleManager.BattleState.DEFEAT:
		_show_battle_result(false)

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
	if enemy_controller != null and enemy_controller.has_method("get_current_attack_preview"):
		turn_label.text = "Turn %d  |  Enemy: %s" % [
			enemy_controller.turn_counter,
			enemy_controller.get_current_attack_preview(),
		]
	else:
		turn_label.text = "Turn 0"

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
	if special_gem_panel != null and battle_controller != null:
		special_gem_panel.set_energy(battle_controller.get_skill_energy())
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
	if battle_controller == null or not battle_controller.has_method("can_use_skill"):
		for button in skill_buttons.values():
			button.disabled = true
		return
	for skill_id in skill_buttons:
		var button: Button = skill_buttons[skill_id]
		button.disabled = not battle_controller.can_use_skill(skill_id)
