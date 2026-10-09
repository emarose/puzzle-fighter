class_name ActorSprite
extends AnimatedSprite2D

enum Side { PLAYER, ENEMY }

const IDLE := &"idle"
const HURT := &"hurt"
const DEATH := &"death"
const ATTACK_PREFIX := "attack_"

@export var side = Side.PLAYER
## Seconds between the opponent starting an attack and this actor reacting.
@export_range(0.0, 2.0, 0.01) var hit_reaction_delay: float = 0.35

var actor_id: String = ""
var attack_animations: Array[StringName] = []
var is_dead: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	var battle: Node = _find_battle_manager()
	var definition: CombatantDefinition = null
	if battle != null:
		definition = battle.player_character if side == Side.PLAYER else battle.enemy_character
	if definition != null:
		configure(definition)
	animation_finished.connect(_on_animation_finished)
	var event_bus: EventBus = EventBus.get_instance()
	if event_bus != null:
		event_bus.event_emitted.connect(_on_event_emitted)

func configure(definition: CombatantDefinition) -> void:
	actor_id = definition.id
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_animation(frames, IDLE, definition.idle_sheet, definition.animation_fps, true)
	_add_animation(frames, HURT, definition.hurt_sheet, definition.animation_fps, false)
	_add_animation(frames, DEATH, definition.death_sheet, definition.animation_fps, false)
	attack_animations.clear()
	for index in range(definition.attack_sheets.size()):
		var animation := StringName("%s%d" % [ATTACK_PREFIX, index])
		if _add_animation(frames, animation, definition.attack_sheets[index], definition.animation_fps, false):
			attack_animations.append(animation)
	sprite_frames = frames
	is_dead = false
	if frames.has_animation(IDLE):
		play(IDLE)

func play_attack() -> void:
	if is_dead or attack_animations.is_empty():
		return
	play(attack_animations[rng.randi_range(0, attack_animations.size() - 1)])

func play_hurt() -> void:
	if is_dead or sprite_frames == null or not sprite_frames.has_animation(HURT):
		return
	play(HURT)

func play_death() -> void:
	if is_dead:
		return
	is_dead = true
	if sprite_frames != null and sprite_frames.has_animation(DEATH):
		play(DEATH)

func _on_animation_finished() -> void:
	if is_dead or sprite_frames == null or not sprite_frames.has_animation(IDLE):
		return
	play(IDLE)

func _on_event_emitted(event_name: String, payload: Dictionary) -> void:
	if actor_id.is_empty():
		return
	match event_name:
		"attack_created":
			if str(payload.get("source", "")) == actor_id and str(payload.get("role", "")) == "DAMAGE":
				play_attack()
		"damage_received":
			if str(payload.get("actor_id", "")) != actor_id:
				return
			_react_to_damage(int(payload.get("current_hp", 1)) <= 0)
		"battle_won":
			if side == Side.ENEMY:
				_react_to_damage(true)
		"battle_lost":
			if side == Side.PLAYER:
				_react_to_damage(true)

func _react_to_damage(fatal: bool) -> void:
	if hit_reaction_delay > 0.0:
		await get_tree().create_timer(hit_reaction_delay).timeout
	if not is_inside_tree():
		return
	if fatal:
		play_death()
	else:
		play_hurt()

func _find_battle_manager() -> Node:
	var node: Node = get_parent()
	while node != null:
		var manager: Node = node.get_node_or_null("BattleManager")
		if manager != null:
			return manager
		node = node.get_parent()
	return null

func _add_animation(
	frames: SpriteFrames,
	animation: StringName,
	sheet: Texture2D,
	fps: float,
	loop: bool
) -> bool:
	if sheet == null:
		return false
	var frame_size: int = sheet.get_height()
	var frame_count: int = sheet.get_width() / frame_size
	if frame_count <= 0:
		return false
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
	for index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(index * frame_size, 0, frame_size, frame_size)
		frames.add_frame(animation, atlas)
	return true
