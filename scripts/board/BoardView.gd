extends Node2D

class_name BoardView

@export var board_columns: int = 6
@export var board_rows: int = 10
@export var cell_size: Vector2 = Vector2(32, 32)
@export var board_manager_path: NodePath
@export var match_highlight_duration: float = 0.4

var board_manager: BoardManager
@onready var match_outline: BoardMatchOutline = $MatchOutline
var background_color: Color = Color(0.10, 0.14, 0.18, 1.0)
var grid_color: Color = Color(0.28, 0.38, 0.46, 1.0)

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
    match_outline.configure(Vector2i(board_columns, board_rows), cell_size)
    queue_redraw()

func show_match_highlight(groups: Array) -> void:
    if groups.is_empty():
        match_outline.clear()
        return
    match_outline.show_groups(groups, board_manager, Callable(self, "color_for_id"))
    await get_tree().create_timer(match_highlight_duration).timeout
    match_outline.clear()

func show_prepared_highlight(groups: Array) -> void:
    if board_manager == null:
        return
    if groups.is_empty():
        match_outline.clear()
        return
    var cell_groups: Array = []
    for group in groups:
        if group is MatchManager.PreparedGroup:
            cell_groups.append(group.cells)
        elif group is Array:
            cell_groups.append(group)
    match_outline.show_groups(cell_groups, board_manager, Callable(self, "color_for_id"))
    visible = true
    queue_redraw()

func find_prepared_group_at_screen_position(screen_position: Vector2, groups: Array, padding: float = 10.0) -> MatchManager.PreparedGroup:
    var local_position: Vector2 = to_local(screen_position)
    var best: MatchManager.PreparedGroup = null
    var best_distance: float = INF
    for group in groups:
        if not (group is MatchManager.PreparedGroup):
            continue
        for cell_position in group.cells:
            if typeof(cell_position) != TYPE_VECTOR2I:
                continue
            var rect := Rect2(Vector2(cell_position) * cell_size, cell_size).grow(padding)
            if not rect.has_point(local_position):
                continue
            var distance: float = rect.get_center().distance_squared_to(local_position)
            if distance < best_distance:
                best_distance = distance
                best = group
    return best

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

    for y in range(board_rows):
        for x in range(board_columns):
            var cell: BoardCell = board_manager.get_cell(Vector2i(x, y))
            if cell.is_empty:
                continue

            var fill_color: Color = color_for_id(cell.color_id)
            var inner_rect: Rect2 = Rect2(
                Vector2(x * cell_size.x + 4, y * cell_size.y + 4),
                cell_size - Vector2(8, 8)
            )
            draw_rect(inner_rect, fill_color)

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
