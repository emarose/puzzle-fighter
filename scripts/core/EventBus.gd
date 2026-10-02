class_name EventBus
extends Node

signal event_emitted(event_name: String, payload: Dictionary)

static var instance: EventBus

func _init() -> void:
    if EventBus.instance == null:
        EventBus.instance = self

static func get_instance() -> EventBus:
    if EventBus.instance == null:
        EventBus.instance = EventBus.new()
    return EventBus.instance

func emit(event_name: String, payload: Dictionary = {}) -> void:
    emit_signal("event_emitted", event_name, payload)
