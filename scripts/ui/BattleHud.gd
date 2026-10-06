extends CanvasLayer

@onready var player_hp_label: Label = $MarginContainer/VBoxContainer/TopRow/PlayerHP
@onready var enemy_hp_label: Label = $MarginContainer/VBoxContainer/TopRow/EnemyHP
@onready var state_label: Label = $MarginContainer/VBoxContainer/State
@onready var enemy_action_label: Label = $MarginContainer/VBoxContainer/EnemyAction
@onready var turn_label: Label = $MarginContainer/VBoxContainer/Turn
@onready var skill_status_label: Label = $MarginContainer/VBoxContainer/SkillStatus
@onready var burst_button: Button = $MarginContainer/VBoxContainer/SkillButtons/BurstButton
@onready var heal_button: Button = $MarginContainer/VBoxContainer/SkillButtons/HealButton
@onready var pulse_button: Button = $MarginContainer/VBoxContainer/SkillButtons/PulseButton

var skill_buttons: Dictionary = {}

var battle_manager: Node
var enemy_controller: Node
var battle_controller: Node
var event_bus: EventBus

func _ready() -> void:
	event_bus = EventBus.get_instance()
	if get_parent() != null:
		battle_manager = get_parent().get_node_or_null("BattleManager")
		enemy_controller = get_parent().get_node_or_null("EnemyController")
		battle_controller = get_parent()

	if battle_manager != null and battle_manager.has_signal("state_changed"):
		battle_manager.state_changed.connect(_on_state_changed)
	if event_bus != null:
		event_bus.event_emitted.connect(_on_event_emitted)

	skill_buttons = {
		"burst": burst_button,
		"heal": heal_button,
		"pulse": pulse_button,
	}
	burst_button.pressed.connect(_on_skill_button_pressed.bind("burst"))
	heal_button.pressed.connect(_on_skill_button_pressed.bind("heal"))
	pulse_button.pressed.connect(_on_skill_button_pressed.bind("pulse"))
	_update_hud()

func _on_state_changed(_old_state: int, _new_state: int) -> void:
	_update_hud()

func _on_skill_button_pressed(skill_id: String) -> void:
	if battle_controller == null or not battle_controller.has_method("use_skill"):
		return
	if not battle_controller.use_skill(skill_id):
		return
	_update_hud()

func _on_event_emitted(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"battle_state_changed":
			if payload.has("state_name"):
				state_label.text = "State: %s" % payload["state_name"]
		"hp_changed":
			var player_actor_id: String = "player"
			var enemy_actor_id: String = "enemy"
			if enemy_controller != null:
				player_actor_id = enemy_controller.player_state.actor_id
				enemy_actor_id = enemy_controller.enemy_state.actor_id
			if payload.get("actor_id", "") == player_actor_id:
				player_hp_label.text = "Player HP: %d" % int(payload.get("current_hp", 0))
			elif payload.get("actor_id", "") == enemy_actor_id:
				enemy_hp_label.text = "Enemy HP: %d" % int(payload.get("current_hp", 0))
		"piece_spawned":
			enemy_action_label.text = "Enemy intent: piece spawned"
		"piece_locked":
			enemy_action_label.text = "Enemy intent: piece locked"
		"cascade_resolved":
			enemy_action_label.text = "Enemy intent: cascade %d" % int(payload.get("cascade_count", 0))
		"skill_energy_changed":
			_update_skill_status()
			if enemy_controller != null and str(payload.get("actor_id", "")) == enemy_controller.player_state.actor_id:
				enemy_action_label.text = "Player energy: %d / 9" % int(payload.get("energy", 0))
		"skill_used":
			_update_skill_status()
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
			_update_skill_status()
			enemy_action_label.text = "%s gained %d guard" % [str(payload.get("actor_id", "")).capitalize(), int(payload.get("amount", 0))]
		"guard_absorbed":
			_update_skill_status()
			enemy_action_label.text = "%s blocked %d damage" % [str(payload.get("actor_id", "")).capitalize(), int(payload.get("amount", 0))]
		"enemy_action_started":
			enemy_action_label.text = "Enemy turn: resolving"
		"enemy_action_finished":
			_update_hud()

func _update_hud() -> void:
	if battle_manager != null:
		var state_name: String = "UNKNOWN"
		if battle_manager.current_state >= 0 and battle_manager.current_state < BattleManager.BattleState.keys().size():
			state_name = BattleManager.BattleState.keys()[battle_manager.current_state]
		state_label.text = "State: %s" % state_name

	if enemy_controller != null and enemy_controller.has_method("get_current_attack_preview"):
		enemy_action_label.text = "Enemy intent: %s" % enemy_controller.get_current_attack_preview()
	else:
		enemy_action_label.text = "Enemy intent: idle"

	if enemy_controller != null and enemy_controller.has_method("get_current_attack_preview"):
		turn_label.text = "Turn: %d" % enemy_controller.turn_counter
	else:
		turn_label.text = "Turn: 0"

	if enemy_controller != null and enemy_controller.get("player_state") != null:
		player_hp_label.text = "Player HP: %d" % enemy_controller.get("player_state").current_hp
	else:
		player_hp_label.text = "Player HP: 100"

	if enemy_controller != null and enemy_controller.get("enemy_state") != null:
		enemy_hp_label.text = "Enemy HP: %d" % enemy_controller.get("enemy_state").current_hp
	else:
		enemy_hp_label.text = "Enemy HP: 100"
	_update_skill_status()

func _update_skill_status() -> void:
	if battle_controller == null:
		for button in skill_buttons.values():
			button.disabled = true
		return
	if battle_controller.has_method("get_skill_energy") and battle_controller.has_method("get_player_guard"):
		skill_status_label.text = "Guard: %d | Energy: %d / 9" % [
			battle_controller.get_player_guard(),
			battle_controller.get_skill_energy(),
		]
	if not battle_controller.has_method("can_use_skill"):
		for button in skill_buttons.values():
			button.disabled = true
		return
	var skill_labels: Dictionary = {
		"burst": "Burst",
		"heal": "Heal",
		"pulse": "Pulse",
	}
	var shortcuts: Dictionary = {
		"burst": "1",
		"heal": "2",
		"pulse": "3",
	}
	for skill_id in skill_buttons:
		var button: Button = skill_buttons[skill_id]
		var cost: int = battle_controller.get_skill_cost(skill_id)
		button.text = "%s (%d) [%s]" % [skill_labels[skill_id], cost, shortcuts[skill_id]]
		button.disabled = not battle_controller.can_use_skill(skill_id)
