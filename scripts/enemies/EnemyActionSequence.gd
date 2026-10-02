class_name EnemyActionSequence
extends RefCounted

var actions: Array = []

func _init() -> void:
    _build_default_sequence()

func _build_default_sequence() -> void:
    actions = [
        {"name": "spawn", "color": "green"},
        {"name": "move", "direction": Vector2i(0, 1)},
        {"name": "rotate", "clockwise": true},
        {"name": "lock"},
        {"name": "resolve"},
        {"name": "attack", "color": "green", "amount": 12},
        {"name": "wait", "delay": 0.25},
    ]

func get_actions() -> Array:
    return actions.duplicate()
