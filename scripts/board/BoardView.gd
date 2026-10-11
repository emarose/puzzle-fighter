extends Node2D

class_name BoardView

@export var board_columns: int = 6
@export var board_rows: int = 10
@export var cell_size: Vector2 = Vector2(40, 40)
@export var board_manager_path: NodePath
@export var match_highlight_duration: float = 0.4
@export var gravity_fall_seconds_per_cell: float = 0.06

var board_manager: BoardManager
@onready var match_fill: BoardMatchFill = $MatchFill
var background_color: Color = Color(0.10, 0.14, 0.18, 1.0)
var grid_color: Color = Color(0.28, 0.38, 0.46, 1.0)
var explosion_cells: Array = []
var explosion_progress: float = 0.0
var explosion_color: Color = Color.WHITE
var explosion_tween: Tween
var gravity_movements: Array = []
var gravity_cells_fallen: int = 0
var gravity_tween: Tween
# Presentation inputs injected by the owner; the view never queries game logic.
var special_gem_icons: Dictionary = {}
var gem_status_provider: Callable = Callable()

func set_special_gem_presentation(icons: Dictionary, status_provider: Callable) -> void:
    special_gem_icons = icons
    gem_status_provider = status_provider
    queue_redraw()

func _ready() -> void:
    if not board_manager_path.is_empty():
        board_manager = get_node_or_null(board_manager_path)
    if board_manager == null:
        board_manager = get_parent().get_node_or_null("BoardManager")
    if board_manager == null:
        var parent_node: Node = get_parent()
        while parent_node != null:
            board_manager = parent_node.get_node_or_null("BoardManager")
            if board_manager != null:
                break
            parent_node = parent_node.get_parent()
    if board_manager == null and get_tree() != null and get_tree().root != null:
        board_manager = get_tree().root.get_node_or_null("Battle/BoardManager")
    if board_manager != null:
        board_columns = int(board_manager.columns)
        board_rows = int(board_manager.rows)
        if not board_manager.gravity_applied.is_connected(_animate_gravity):
            board_manager.gravity_applied.connect(_animate_gravity)
    match_fill.configure(Vector2i(board_columns, board_rows), cell_size)
    queue_redraw()

func show_match_highlight(groups: Array) -> void:
    if groups.is_empty():
        match_fill.clear()
        return
    match_fill.show_groups(groups, board_manager, Callable(self, "color_for_id"))
    await get_tree().create_timer(match_highlight_duration).timeout
    match_fill.clear()

func show_prepared_highlight(groups: Array) -> void:
    if board_manager == null:
        return
    if groups.is_empty():
        match_fill.clear()
        return
    var cell_groups: Array = []
    for group in groups:
        if group is MatchManager.PreparedGroup:
            cell_groups.append(group.cells)
        elif group is Array:
            cell_groups.append(group)
    match_fill.show_groups(cell_groups, board_manager, Callable(self, "color_for_id"))
    visible = true
    queue_redraw()

func play_group_explosion(group: MatchManager.PreparedGroup) -> void:
    if group == null or group.cells.is_empty():
        return
    if explosion_tween != null and explosion_tween.is_running():
        explosion_tween.kill()
    explosion_cells = group.cells.duplicate()
    explosion_color = color_for_id(group.color_id)
    explosion_progress = 0.0
    explosion_tween = create_tween()
    explosion_tween.tween_method(
        Callable(self, "_set_explosion_progress"),
        0.0,
        1.0,
        0.24
    )
    explosion_tween.tween_callback(Callable(self, "_clear_explosion"))

const EXPLOSION_SECONDS := 0.24

# Pops a fading label over a detonated group, timed to appear as its blocks vanish.
func show_detonation_label(group: MatchManager.PreparedGroup, text: String, subtitle: String = "") -> void:
    if group == null or group.cells.is_empty():
        return
    var bounds := Rect2()
    var has_cells := false
    for cell_position in group.cells:
        var cell_rect := Rect2(Vector2(cell_position) * cell_size, cell_size)
        bounds = cell_rect if not has_cells else bounds.merge(cell_rect)
        has_cells = true
    var center: Vector2 = bounds.get_center()
    var margin: float = cell_size.x * 1.2
    center.x = clampf(center.x, margin, board_columns * cell_size.x - margin)
    center.y = maxf(center.y, cell_size.y)
    DetonationLabel.spawn(self, center, text, color_for_id(group.color_id), subtitle, EXPLOSION_SECONDS)

func _set_explosion_progress(progress: float) -> void:
    explosion_progress = progress
    queue_redraw()

func _clear_explosion() -> void:
    explosion_cells.clear()
    explosion_tween = null
    queue_redraw()

func _animate_gravity(movements: Array) -> void:
    if movements.is_empty():
        return
    if gravity_tween != null and gravity_tween.is_running():
        gravity_tween.kill()

    gravity_movements = movements.duplicate(true)
    gravity_cells_fallen = 0
    var longest_fall: int = 1
    for movement in gravity_movements:
        var source: Vector2i = movement.get("from", Vector2i.ZERO)
        var destination: Vector2i = movement.get("to", source)
        longest_fall = maxi(longest_fall, destination.y - source.y)

    gravity_tween = create_tween()
    gravity_tween.tween_method(
        Callable(self, "_set_gravity_cells_fallen"),
        0.0,
        float(longest_fall),
        longest_fall * gravity_fall_seconds_per_cell
    )
    gravity_tween.tween_callback(Callable(self, "_clear_gravity_animation"))

# Whole cells only, so blocks hop cell by cell instead of sliding.
func _set_gravity_cells_fallen(cells: float) -> void:
    var whole_cells: int = int(floor(cells))
    if whole_cells != gravity_cells_fallen:
        gravity_cells_fallen = whole_cells
        queue_redraw()

func _clear_gravity_animation() -> void:
    gravity_movements.clear()
    gravity_cells_fallen = 0
    gravity_tween = null
    queue_redraw()

func find_prepared_group_at_screen_position(screen_position: Vector2, groups: Array, padding: float = 12.0) -> MatchManager.PreparedGroup:
    var local_position: Vector2 = to_local(screen_position)
    var best: MatchManager.PreparedGroup = null
    var best_distance: float = INF
    for group in groups:
        if not (group is MatchManager.PreparedGroup):
            continue
        var touch_rect := _prepared_group_touch_rect(group, padding)
        if touch_rect.size == Vector2.ZERO or not touch_rect.has_point(local_position):
            continue
        var distance: float = touch_rect.get_center().distance_squared_to(local_position)
        if distance < best_distance:
            best_distance = distance
            best = group
    return best

func _prepared_group_touch_rect(group: MatchManager.PreparedGroup, padding: float) -> Rect2:
    var bounds := Rect2()
    var has_cells := false
    for cell_position in group.cells:
        if typeof(cell_position) != TYPE_VECTOR2I:
            continue
        var cell_rect := Rect2(Vector2(cell_position) * cell_size, cell_size)
        bounds = cell_rect if not has_cells else bounds.merge(cell_rect)
        has_cells = true
    return bounds.grow(padding) if has_cells else Rect2()

func screen_position_to_cell(screen_position: Vector2) -> Vector2i:
    if board_manager == null:
        return Vector2i(-1, -1)
    var local_position: Vector2 = to_local(screen_position)
    var cell_x: int = int(floor(local_position.x / cell_size.x))
    var cell_y: int = int(floor(local_position.y / cell_size.y))
    var cell := Vector2i(cell_x, cell_y)
    if not board_manager.is_within_bounds(cell):
        return Vector2i(-1, -1)
    return cell

func _draw() -> void:
    var width: float = board_columns * cell_size.x
    var height: float = board_rows * cell_size.y
    draw_rect(Rect2(Vector2.ZERO, Vector2(width, height)), background_color)

    for y in range(board_rows):
        for x in range(board_columns):
            var rect: Rect2 = Rect2(Vector2(x * cell_size.x, y * cell_size.y), cell_size)
            draw_rect(rect, grid_color, false)

    if board_manager == null:
        return

    var animated_destinations: Dictionary = {}
    for movement in gravity_movements:
        var destination: Vector2i = movement.get("to", Vector2i(-1, -1))
        animated_destinations[board_manager.cell_key(destination)] = true

    for y in range(board_rows):
        for x in range(board_columns):
            var cell_position := Vector2i(x, y)
            if animated_destinations.has(board_manager.cell_key(cell_position)):
                continue
            var cell: BoardCell = board_manager.get_cell(cell_position)
            if cell.is_empty:
                continue

            var fill_color: Color = color_for_id(cell.color_id)
            var cell_inset := cell_size.x * 0.125
            var inner_rect: Rect2 = Rect2(
                Vector2(x * cell_size.x + cell_inset, y * cell_size.y + cell_inset),
                cell_size - Vector2(cell_inset * 2.0, cell_inset * 2.0)
            )
            draw_rect(inner_rect, fill_color)
            if not cell.special_gem_id.is_empty():
                _draw_special_gem_marker(inner_rect, cell.special_gem_id, fill_color, Vector2i(x, y))

    for movement in gravity_movements:
        var source: Vector2i = movement.get("from", Vector2i.ZERO)
        var destination: Vector2i = movement.get("to", source)
        var fall_distance: int = destination.y - source.y
        var position := Vector2(source.x, source.y + mini(gravity_cells_fallen, fall_distance))
        var cell_inset := cell_size.x * 0.125
        var inner_rect := Rect2(
            position * cell_size + Vector2(cell_inset, cell_inset),
            cell_size - Vector2(cell_inset * 2.0, cell_inset * 2.0)
        )
        var moving_color: Color = color_for_id(str(movement.get("color_id", "")))
        draw_rect(inner_rect, moving_color)
        var gem_id: String = str(movement.get("special_gem_id", ""))
        if not gem_id.is_empty():
            _draw_special_gem_marker(inner_rect, gem_id, moving_color)

    for cell_position in explosion_cells:
        if typeof(cell_position) != TYPE_VECTOR2I:
            continue
        var center: Vector2 = (Vector2(cell_position) + Vector2(0.5, 0.5)) * cell_size
        var radius: float = 5.0 + 15.0 * explosion_progress
        var fade: float = 1.0 - explosion_progress
        var particle_color: Color = Color(
            explosion_color.r,
            explosion_color.g,
            explosion_color.b,
            fade
        )
        draw_circle(center, 3.0 * fade, particle_color)
        for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
            draw_line(
                center + direction * radius * 0.4,
                center + direction * radius,
                particle_color,
                2.0
            )

func _draw_special_gem_marker(rect: Rect2, gem_id: String, block_color: Color, cell_position: Vector2i = Vector2i(-1, -1)) -> void:
    var icon: Texture2D = special_gem_icons.get(gem_id) as Texture2D
    var status: int = SpecialGemGlyph.Status.IDLE
    if gem_status_provider.is_valid():
        status = int(gem_status_provider.call(cell_position))
    SpecialGemGlyph.draw_badge(self, rect, icon, status, block_color)

func color_for_id(color_id: String) -> Color:
    match color_id:
        "red":
            return Color(0.94, 0.31, 0.36, 1.0)
        "blue":
            return Color(0.36, 0.61, 1.0, 1.0)
        "green":
            return Color(0.39, 0.82, 0.56, 1.0)
        "yellow":
            return Color(1.0, 0.86, 0.25, 1.0)
        _:
            return Color(0.75, 0.75, 0.75, 1.0)
