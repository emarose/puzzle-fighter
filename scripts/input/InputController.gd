class_name InputController
extends Node

signal command_executed(command_name: String, success: bool)

@export var battle_controller_path: NodePath

var battle_controller: Node
var movement_map: Dictionary = {
    "left": Vector2i(-1, 0),
    "right": Vector2i(1, 0),
    "down": Vector2i(0, 1),
}

func _ready() -> void:
    if battle_controller_path.is_empty():
        battle_controller = get_parent()
    else:
        battle_controller = get_node_or_null(battle_controller_path)

func bind_battle_controller(controller: Node) -> void:
    battle_controller = controller

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_LEFT or event.keycode == KEY_A:
            try_move_left()
        elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
            try_move_right()
        elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
            try_soft_drop()
        elif event.keycode == KEY_UP or event.keycode == KEY_W or event.keycode == KEY_X:
            try_rotate()
        elif event.keycode == KEY_SPACE:
            try_hard_drop()
        elif event.keycode == KEY_1:
            try_use_skill_slot(0)
        elif event.keycode == KEY_2:
            try_use_skill_slot(1)
        elif event.keycode == KEY_3:
            try_use_skill_slot(2)
        elif event.keycode == KEY_P:
            _toggle_pause()

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

func _toggle_pause() -> void:
    emit_signal("command_executed", "pause", true)

func _execute_command(command_name: String, action: Callable) -> bool:
    if battle_controller == null:
        emit_signal("command_executed", command_name, false)
        return false

    var success: bool = bool(action.call())
    emit_signal("command_executed", command_name, success)
    return success
