class_name ArcadeJoystick
extends Control

signal direction_changed(direction: StringName)
signal direction_repeated(direction: StringName)

const DEADZONE_RATIO := 0.28
const KNOB_TRAVEL_RATIO := 0.48
const REPEAT_DELAY := 0.24
const REPEAT_INTERVAL := 0.16

const REST_COLOR := Color(0.78, 0.16, 0.35, 1.0)
const ACTIVE_COLOR := Color(1.0, 0.30, 0.44, 1.0)

@export var base_texture: Texture2D

var _active_touch_index := -1
var _mouse_active := false
var _direction: StringName = &""
var _stick_offset := Vector2.ZERO
var _repeat_elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			queue_redraw()
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_release_stick()

func _process(delta: float) -> void:
	if get_tree() != null and get_tree().paused:
		_release_stick()
		return
	if _direction == &"":
		return
	_repeat_elapsed += delta
	if _repeat_elapsed >= REPEAT_DELAY:
		_repeat_elapsed -= REPEAT_INTERVAL
		direction_repeated.emit(_direction)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _active_touch_index >= 0 or _mouse_active:
				accept_event()
				return
			_active_touch_index = event.index
			_update_stick(_screen_position_to_local(event.position))
		elif event.index == _active_touch_index:
			_release_stick()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _active_touch_index:
		_update_stick(_screen_position_to_local(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _active_touch_index >= 0 or _mouse_active:
				accept_event()
				return
			_mouse_active = true
			_update_stick(get_local_mouse_position())
		elif _mouse_active:
			_release_stick()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_stick(get_local_mouse_position())
		accept_event()

func _screen_position_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position

func _update_stick(local_position: Vector2) -> void:
	var center := size * 0.5
	var delta := local_position - center
	var base_radius := _base_radius()
	var max_travel := base_radius * KNOB_TRAVEL_RATIO
	_stick_offset = delta.limit_length(max_travel)

	var next_direction: StringName = &""
	if delta.length() >= base_radius * DEADZONE_RATIO:
		if absf(delta.x) > absf(delta.y):
			next_direction = &"right" if delta.x > 0.0 else &"left"
		elif delta.y > 0.0:
			next_direction = &"down"

	if next_direction != _direction:
		_direction = next_direction
		_repeat_elapsed = 0.0
		direction_changed.emit(_direction)
	queue_redraw()

func _release_stick() -> void:
	_active_touch_index = -1
	_mouse_active = false
	_stick_offset = Vector2.ZERO
	if _direction != &"":
		_direction = &""
		direction_changed.emit(_direction)
	_repeat_elapsed = 0.0
	queue_redraw()

func _base_radius() -> float:
	return maxf(16.0, minf(size.x * 0.37, size.y * 0.42))

func _draw() -> void:
	var center := size * 0.5
	var radius := _base_radius()
	var knob_radius := radius * 0.36
	var active_color := ACTIVE_COLOR if _direction != &"" else REST_COLOR

	var base_size := radius * 2.6
	var texture_size := base_texture.get_size()
	var draw_size := texture_size * minf(base_size / texture_size.x, base_size / texture_size.y)
	draw_texture_rect(base_texture, Rect2(center - draw_size * 0.5, draw_size), false)
	_draw_direction_marks(center, radius)

	var knob_center := center + _stick_offset
	draw_line(center, knob_center, Color(0.18, 0.22, 0.29, 1.0), maxf(5.0, knob_radius * 0.52))
	draw_circle(knob_center + Vector2(0.0, 2.0), knob_radius + 1.0, Color(0.0, 0.0, 0.0, 0.55))
	draw_circle(knob_center, knob_radius, active_color.darkened(0.35))
	draw_circle(knob_center, knob_radius * 0.78, active_color)
	draw_circle(knob_center + Vector2(-knob_radius * 0.22, -knob_radius * 0.25), knob_radius * 0.19, Color(1.0, 0.75, 0.78, 0.82))

func _draw_direction_marks(center: Vector2, radius: float) -> void:
	var mark_color := Color(0.55, 0.64, 0.72, 0.75)
	_draw_arrow(center + Vector2(-radius * 0.63, 0.0), Vector2.LEFT, mark_color)
	_draw_arrow(center + Vector2(radius * 0.63, 0.0), Vector2.RIGHT, mark_color)
	_draw_arrow(center + Vector2(0.0, radius * 0.63), Vector2.DOWN, mark_color)

func _draw_arrow(origin: Vector2, direction: Vector2, color: Color) -> void:
	var tip := origin + direction * 3.0
	var tail := origin - direction * 3.0
	var perpendicular := Vector2(-direction.y, direction.x) * 2.5
	draw_line(tail, tip, color, 1.5)
	draw_line(tip, tip - direction * 3.0 + perpendicular, color, 1.5)
	draw_line(tip, tip - direction * 3.0 - perpendicular, color, 1.5)
