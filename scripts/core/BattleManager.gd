class_name BattleManager
extends Node

enum BattleState {
	INITIALIZING,
	PLAYING,
	PIECE_ACTIVE,
	RESOLVING,
	ENEMY_ACTION,
	PLAYER_DEFEATED,
	ENEMY_DEFEATED,
	VICTORY,
	DEFEAT,
}

signal state_changed(old_state: BattleState, new_state: BattleState)

const PLAYER_CONTROLLED_STATES: Array = [
	BattleState.PLAYING,
	BattleState.PIECE_ACTIVE,
]

const RESOLUTION_STATES: Array = [
	BattleState.RESOLVING,
]

var current_state: BattleState = BattleState.INITIALIZING
@export var player_character: CharacterDefinition
@export var enemy_character: EnemyDefinition
@export var combat_tuning: CombatTuning
@export var skill_catalog: SkillCatalog
var event_bus: EventBus

func _ready() -> void:
	event_bus = EventBus.get_instance()
	if current_state == BattleState.INITIALIZING:
		start_battle()

func _initialize_characters() -> bool:
	if player_character == null:
		player_character = load("res://resources/characters/default_player.tres")
	if enemy_character == null:
		enemy_character = load("res://resources/enemies/default_enemy.tres")
	if player_character == null or enemy_character == null:
		push_error("BattleManager could not load the player or enemy definition resource.")
		return false
	if enemy_character.turn_pattern == null:
		enemy_character.turn_pattern = load("res://resources/enemies/default_turn_pattern.tres")
	if player_character.available_colors.is_empty():
		player_character.available_colors = ["red", "blue", "green", "yellow"]
	if enemy_character.available_colors.is_empty():
		enemy_character.available_colors = ["red", "blue", "green", "yellow"]
	if combat_tuning == null:
		combat_tuning = load("res://resources/combat_tuning.tres")
	if skill_catalog == null:
		skill_catalog = load("res://resources/skills/default_skill_catalog.tres")
	if combat_tuning == null or skill_catalog == null or enemy_character.turn_pattern == null:
		push_error("BattleManager could not load combat tuning, skills, or enemy turn pattern resources.")
		return false
	return true

func start_battle() -> void:
	if not _initialize_characters():
		return
	if current_state == BattleState.PLAYING:
		return

	_transition_to(BattleState.PLAYING)

func set_state(new_state: BattleState) -> bool:
	return _transition_to(new_state)

func can_player_act() -> bool:
	return current_state in PLAYER_CONTROLLED_STATES

func can_enemy_act() -> bool:
	return current_state == BattleState.ENEMY_ACTION

func is_resolution_state() -> bool:
	return current_state in RESOLUTION_STATES

func is_input_blocked() -> bool:
	return not can_player_act() and not can_enemy_act()

func _transition_to(new_state: BattleState) -> bool:
	if not is_valid_transition(current_state, new_state):
		push_warning(
			"Invalid battle state transition: %s -> %s" % [
				BattleState.keys()[current_state],
				BattleState.keys()[new_state],
			]
		)
		return false

	var previous_state: BattleState = current_state
	current_state = new_state
	emit_signal("state_changed", previous_state, current_state)
	if event_bus != null:
		event_bus.emit("battle_state_changed", {
			"previous_state": int(previous_state),
			"new_state": int(current_state),
			"state_name": BattleState.keys()[current_state],
		})
	return true

func register_outcome(player_hp: int, enemy_hp: int) -> void:
	if current_state in [BattleState.VICTORY, BattleState.DEFEAT]:
		return
	if enemy_hp <= 0:
		if _transition_to(BattleState.VICTORY) and event_bus != null:
			event_bus.emit("battle_won", {"enemy_hp": enemy_hp, "player_hp": player_hp})
		return
	if player_hp <= 0:
		if _transition_to(BattleState.DEFEAT) and event_bus != null:
			event_bus.emit("battle_lost", {"player_hp": player_hp, "enemy_hp": enemy_hp})
		return
	if current_state in [BattleState.PLAYING, BattleState.PIECE_ACTIVE, BattleState.RESOLVING]:
		return
	if current_state == BattleState.ENEMY_ACTION:
		_transition_to(BattleState.PLAYING)
		return

func is_valid_transition(old_state: BattleState, new_state: BattleState) -> bool:
	match old_state:
		BattleState.INITIALIZING:
			return new_state == BattleState.PLAYING

		BattleState.PLAYING:
			return new_state in [
				BattleState.PIECE_ACTIVE,
				BattleState.RESOLVING,
				BattleState.ENEMY_ACTION,
				BattleState.PLAYER_DEFEATED,
				BattleState.ENEMY_DEFEATED,
				BattleState.VICTORY,
				BattleState.DEFEAT,
			]

		BattleState.PIECE_ACTIVE:
			return new_state in [
				BattleState.RESOLVING,
				BattleState.PLAYING,
				BattleState.PLAYER_DEFEATED,
				BattleState.ENEMY_DEFEATED,
				BattleState.VICTORY,
				BattleState.DEFEAT,
			]

		BattleState.RESOLVING:
			return new_state in [
				BattleState.PLAYING,
				BattleState.ENEMY_ACTION,
				BattleState.PLAYER_DEFEATED,
				BattleState.ENEMY_DEFEATED,
				BattleState.VICTORY,
				BattleState.DEFEAT,
			]

		BattleState.ENEMY_ACTION:
			return new_state in [
				BattleState.PLAYING,
				BattleState.PIECE_ACTIVE,
				BattleState.PLAYER_DEFEATED,
				BattleState.ENEMY_DEFEATED,
				BattleState.VICTORY,
				BattleState.DEFEAT,
			]

		BattleState.PLAYER_DEFEATED:
			return new_state == BattleState.DEFEAT

		BattleState.ENEMY_DEFEATED:
			return new_state == BattleState.VICTORY

		BattleState.VICTORY:
			return new_state == BattleState.VICTORY

		BattleState.DEFEAT:
			return new_state == BattleState.DEFEAT

		_:
			return false
