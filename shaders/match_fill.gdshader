shader_type canvas_item;
render_mode unshaded;

uniform sampler2D match_colors : filter_nearest, repeat_disable;
uniform vec2 board_dimensions = vec2(6.0, 10.0);
uniform vec2 cell_dimensions = vec2(32.0, 32.0);
uniform float grid_gap_px = 1.0;
uniform float fill_alpha = 0.55;
uniform float shimmer_speed = 5.0;
uniform float shimmer_scale = 0.03;
uniform float shimmer_width = 0.15;
uniform float shimmer_boost = 0.45;

void fragment() {
	vec2 board_position = UV * board_dimensions;
	vec2 cell = floor(board_position);
	vec2 local_position = fract(board_position) * cell_dimensions;
	vec4 match_color = texture(match_colors, (cell + vec2(0.5)) / board_dimensions);

	// Leave the board's own grid lines visible between matched cells.
	vec2 edge_distance = min(local_position, cell_dimensions - local_position);
	bool in_gap = min(edge_distance.x, edge_distance.y) < grid_gap_px;

	if (match_color.a < 0.5 || in_gap) {
		COLOR = vec4(0.0);
	} else {
		// Diagonal band that travels across the board, continuous between cells.
		vec2 board_px = UV * board_dimensions * cell_dimensions;
		float phase = (board_px.x + board_px.y) * shimmer_scale - TIME * shimmer_speed;
		float band = smoothstep(1.0 - shimmer_width, 1.0, sin(phase) * 0.5 + 0.5);

		vec3 rgb = mix(match_color.rgb, vec3(1.0), band * 0.65);
		COLOR = vec4(rgb, clamp(fill_alpha + band * shimmer_boost, 0.0, 1.0));
	}
}
