class_name InputController
extends Node

signal command_executed(command_name: String, success: bool)
signal pause_requested

const SWIPE_THRESHOLD: float = 40.0

@export var battle_controller_path: NodePath

var battle_controller: Node
var battle_manager: Node
var active_touch_index: int = -1
var touch_start_position: Vector2 = Vector2.ZERO
var touch_current_position: Vector2 = Vector2.ZERO
var movement_map: Dictionary = {
    "left": Vector2i(-1, 0),
    "right": Vector2i(1, 0),
    "down": Vector2i(0, 1),
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _refresh_battle_references()

func bind_battle_controller(controller: Node) -> void:
    battle_controller = controller
    _refresh_battle_references()

func _refresh_battle_references() -> void:
    if battle_controller == null:
        if not battle_controller_path.is_empty():
            battle_controller = get_node_or_null(battle_controller_path)
        if battle_controller == null:
            battle_controller = get_parent()
    if battle_controller != null:
        battle_manager = battle_controller.get_node_or_null("BattleManager")
    else:
        battle_manager = get_node_or_null("BattleManager")

func _can_accept_player_input() -> bool:
    if battle_manager != null and battle_manager.has_method("can_player_act"):
        return bool(battle_manager.can_player_act())
    if battle_controller != null and battle_controller.has_method("can_player_act"):
        return bool(battle_controller.can_player_act())
    return true

func _can_execute_command() -> bool:
    return battle_controller != null and _can_accept_player_input()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_screen_touch(event)
        return
    if event is InputEventScreenDrag:
        _handle_screen_drag(event)
        return
    if not (event is InputEventKey) or not event.pressed or event.is_echo():
        return

    if event.keycode == KEY_P:
        try_pause()
        return

    if get_tree().paused:
        return

    if not _can_execute_command():
        return

    match event.keycode:
        KEY_LEFT, KEY_A:
            try_move_left()
        KEY_RIGHT, KEY_D:
            try_move_right()
        KEY_DOWN, KEY_S:
            try_soft_drop()
        KEY_UP, KEY_W, KEY_X:
            try_rotate()
        KEY_SPACE:
            try_hard_drop()
        KEY_1:
            try_use_skill_slot(0)
        KEY_2:
            try_use_skill_slot(1)
        KEY_3:
            try_use_skill_slot(2)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        if active_touch_index >= 0 or get_tree().paused or not _can_execute_command():
            return
        active_touch_index = event.index
        touch_start_position = event.position
        touch_current_position = event.position
        return

    if event.index != active_touch_index:
        return

    touch_current_position = event.position
    var swipe_delta: Vector2 = touch_current_position - touch_start_position
    active_touch_index = -1
    if get_tree().paused or not _can_execute_command():
        return

    if swipe_delta.length() < SWIPE_THRESHOLD:
        _handle_tap(touch_current_position)
        return

    _execute_swipe(swipe_delta)

func _handle_tap(screen_position: Vector2) -> void:
    if battle_controller == null or not battle_controller.has_method("try_resolve_prepared_group_at_screen_position"):
        return
    battle_controller.try_resolve_prepared_group_at_screen_position(screen_position)

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
    if event.index != active_touch_index:
        return
    touch_current_position = event.position

func _execute_swipe(swipe_delta: Vector2) -> void:
    if swipe_delta.length() < SWIPE_THRESHOLD:
        return
    if absf(swipe_delta.x) > absf(swipe_delta.y):
        if swipe_delta.x < 0.0:
            try_move_left()
        else:
            try_move_right()
    elif swipe_delta.y < 0.0:
        try_rotate()
    else:
        try_soft_drop()

func try_move_left() -> bool:
    return _execute_command("move_left", func() -> bool:
        return battle_controller != null and battle_controller.try_move(Vector2i(-1, 0))
    )

func try_move_right() -> bool:
    return _execute_command("move_right", func() -> bool:
        return battle_controller != null and battle_controller.try_move(Vector2i(1, 0))
    )

func try_soft_drop() -> bool:
    return _execute_command("soft_drop", func() -> bool:
        return battle_controller != null and battle_controller.try_move(Vector2i(0, 1))
    )

func try_rotate() -> bool:
    return _execute_command("rotate", func() -> bool:
        return battle_controller != null and battle_controller.try_rotate(true)
    )

func try_hard_drop() -> bool:
    return _execute_command("hard_drop", func() -> bool:
        return battle_controller != null and battle_controller.hard_drop()
    )

func try_use_skill(skill_id: String) -> bool:
    return _execute_command("skill_" + skill_id, func() -> bool:
        return battle_controller != null and battle_controller.use_skill(skill_id)
    )

func try_use_skill_slot(slot_index: int) -> bool:
    if battle_controller == null or not battle_controller.has_method("get_skill_for_slot"):
        emit_signal("command_executed", "skill_slot_%d" % slot_index, false)
        return false
    var skill_id: String = battle_controller.get_skill_for_slot(slot_index)
    if skill_id.is_empty():
        emit_signal("command_executed", "skill_slot_%d" % slot_index, false)
        return false
    return try_use_skill(skill_id)

func try_pause() -> void:
    pause_requested.emit()
    emit_signal("command_executed", "pause", true)

func _execute_command(command_name: String, action: Callable) -> bool:
    if battle_controller == null:
        emit_signal("command_executed", command_name, false)
        return false
    if not _can_accept_player_input():
        emit_signal("command_executed", command_name, false)
        return false

    var success: bool = bool(action.call())
    emit_signal("command_executed", command_name, success)
    return success
