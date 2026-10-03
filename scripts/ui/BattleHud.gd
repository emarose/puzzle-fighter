extends CanvasLayer

@onready var player_hp_label: Label = $MarginContainer/VBoxContainer/TopRow/PlayerHP
@onready var enemy_hp_label: Label = $MarginContainer/VBoxContainer/TopRow/EnemyHP
@onready var state_label: Label = $MarginContainer/VBoxContainer/State
@onready var enemy_action_label: Label = $MarginContainer/VBoxContainer/EnemyAction
@onready var turn_label: Label = $MarginContainer/VBoxContainer/Turn

var battle_manager: Node
var enemy_controller: Node
var event_bus: EventBus

func _ready() -> void:
	event_bus = EventBus.get_instance()
	if get_parent() != null:
		battle_manager = get_parent().get_node_or_null("BattleManager")
		enemy_controller = get_parent().get_node_or_null("EnemyController")

	if battle_manager != null and battle_manager.has_signal("state_changed"):
		battle_manager.state_changed.connect(_on_state_changed)
	if event_bus != null:
		event_bus.event_emitted.connect(_on_event_emitted)

	_update_hud()

func _on_state_changed(_old_state: int, _new_state: int) -> void:
	_update_hud()

func _on_event_emitted(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"battle_state_changed":
			if payload.has("state_name"):
				state_label.text = "State: %s" % payload["state_name"]
		"hp_changed":
			if payload.get("actor_id", "") == "player":
				player_hp_label.text = "Player HP: %d" % int(payload.get("current_hp", 0))
			elif payload.get("actor_id", "") == "enemy":
				enemy_hp_label.text = "Enemy HP: %d" % int(payload.get("current_hp", 0))
		"piece_spawned":
			enemy_action_label.text = "Enemy intent: piece spawned"
		"piece_locked":
			enemy_action_label.text = "Enemy intent: piece locked"
		"cascade_resolved":
			enemy_action_label.text = "Enemy intent: cascade %d" % int(payload.get("cascade_count", 0))

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
