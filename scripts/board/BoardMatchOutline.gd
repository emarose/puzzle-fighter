class_name BoardMatchOutline
extends Node2D

const OUTLINE_SHADER: Shader = preload("res://shaders/match_outline.gdshader")

var board_dimensions: Vector2i = Vector2i(6, 10)
var cell_dimensions: Vector2 = Vector2(32, 32)
var outline_material: ShaderMaterial
var match_colors_texture: ImageTexture

func _ready() -> void:
	outline_material = ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	material = outline_material
	outline_material.set_shader_parameter("board_dimensions", Vector2(board_dimensions))
	outline_material.set_shader_parameter("cell_dimensions", cell_dimensions)
	visible = false

func configure(p_board_dimensions: Vector2i, p_cell_dimensions: Vector2) -> void:
	board_dimensions = p_board_dimensions
	cell_dimensions = p_cell_dimensions
	if outline_material != null:
		outline_material.set_shader_parameter("board_dimensions", Vector2(board_dimensions))
		outline_material.set_shader_parameter("cell_dimensions", cell_dimensions)
	queue_redraw()

func show_groups(
	groups: Array,
	board: BoardManager,
	color_lookup: Callable
) -> void:
	if board == null or not color_lookup.is_valid():
		return

	var image: Image = Image.create(
		board_dimensions.x,
		board_dimensions.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color.TRANSPARENT)
	for group in groups:
		for position in group:
			if typeof(position) != TYPE_VECTOR2I or not board.is_within_bounds(position):
				continue
			var cell: BoardCell = board.get_cell(position)
			if cell.is_empty:
				continue
			var color: Color = color_lookup.call(cell.color_id)
			image.set_pixel(position.x, position.y, Color(color.r, color.g, color.b, 1.0))

	match_colors_texture = ImageTexture.create_from_image(image)
	outline_material.set_shader_parameter("match_colors", match_colors_texture)
	visible = true
	queue_redraw()

func clear() -> void:
	visible = false
	queue_redraw()

func _draw() -> void:
	var size: Vector2 = Vector2(board_dimensions) * cell_dimensions
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])
	var uvs := PackedVector2Array([
		Vector2.ZERO,
		Vector2.RIGHT,
		Vector2.ONE,
		Vector2.DOWN,
	])
	draw_colored_polygon(points, Color.WHITE, uvs)
