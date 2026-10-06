shader_type canvas_item;
render_mode unshaded;

uniform sampler2D match_colors : filter_nearest, repeat_disable;
uniform vec2 board_dimensions = vec2(6.0, 10.0);
uniform vec2 cell_dimensions = vec2(32.0, 32.0);
uniform float outline_width_px = 2.0;

bool is_matched_cell(vec2 cell) {
	if (cell.x < 0.0
		|| cell.y < 0.0
		|| cell.x >= board_dimensions.x
		|| cell.y >= board_dimensions.y) {
		return false;
	}

	vec2 sample_uv = (cell + vec2(0.5)) / board_dimensions;
	return texture(match_colors, sample_uv).a > 0.5;
}

void fragment() {
	vec2 board_position = UV * board_dimensions;
	vec2 cell = floor(board_position);
	vec2 local_position = fract(board_position) * cell_dimensions;
	vec4 match_color = texture(match_colors, (cell + vec2(0.5)) / board_dimensions);

	if (match_color.a < 0.5) {
		COLOR = vec4(0.0);
	} else {
		float inner_edge = 4.0;
		float outer_edge = inner_edge + outline_width_px;
		bool outline_left = local_position.x >= inner_edge - outline_width_px
			&& local_position.x <= outer_edge
			&& !is_matched_cell(cell + vec2(-1.0, 0.0));
		bool outline_right = local_position.x >= cell_dimensions.x - outer_edge
			&& local_position.x <= cell_dimensions.x - inner_edge + outline_width_px
			&& !is_matched_cell(cell + vec2(1.0, 0.0));
		bool outline_top = local_position.y >= inner_edge - outline_width_px
			&& local_position.y <= outer_edge
			&& !is_matched_cell(cell + vec2(0.0, -1.0));
		bool outline_bottom = local_position.y >= cell_dimensions.y - outer_edge
			&& local_position.y <= cell_dimensions.y - inner_edge + outline_width_px
			&& !is_matched_cell(cell + vec2(0.0, 1.0));

		float alpha = float(outline_left || outline_right || outline_top || outline_bottom);
		COLOR = vec4(match_color.rgb, alpha * 0.95);
	}
}
