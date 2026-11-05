// Grey-box material: a flat color with a 1 meter grid drawn on it in world
// space, so you can judge distances and heights at a glance.
//
// After dark (the night_glow global, 0 by day up to 1 at night: see
// game/time_of_day.gd) coloured things glow a little so they stay easy to
// read (the more colourful, the more: white and grey buildings don't), and
// on materials with `windows` some of the walls' windows are lit.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.6);
uniform vec3 line_color : source_color = vec3(0.4);
uniform float grid_size = 1.0;
uniform float line_width = 0.025;
// Lit windows at night, in a pattern up the walls (a window each WINDOW
// along, a floor each storey: 3.5 m).
uniform bool windows = false;
global uniform float night_glow;

const vec2 WINDOW_CELL = vec2(3.0, 3.5);
const vec3 WINDOW_LIGHT = vec3(1.0, 0.7, 0.35);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	// Project the grid onto whichever axis the surface mostly faces.
	vec3 n = abs(world_normal);
	vec2 uv = n.y >= max(n.x, n.z) ? world_pos.xz : (n.x >= n.z ? world_pos.zy : world_pos.xy);
	vec2 to_line = abs(fract(uv / grid_size + 0.5) - 0.5) * grid_size;
	float d = min(to_line.x, to_line.y);
	float aa = fwidth(d);
	float line = 1.0 - smoothstep(line_width - aa, line_width + aa, d);
	// Far away the lines would blur into a haze: fade them out, leaving clean surfaces.
	line *= 1.0 - smoothstep(0.02, 0.08, aa);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.85;
	if (night_glow > 0.0) {
		float colourful = max(base_color.r, max(base_color.g, base_color.b)) - min(base_color.r, min(base_color.g, base_color.b));
		vec3 glow = base_color * smoothstep(0.15, 0.45, colourful) * 0.6;
		if (windows && n.y < 0.3 && world_pos.y > 1.0) {
			vec2 cell = floor(uv / WINDOW_CELL);
			vec2 in_cell = fract(uv / WINDOW_CELL);
			float pane = step(0.2, in_cell.x) * step(in_cell.x, 0.8) * step(0.3, in_cell.y) * step(in_cell.y, 0.75);
			float lit = step(0.58, hash3(vec3(cell, floor(dot(world_normal, vec3(1.0, 2.0, 3.0)) + 0.5))));
			float warmth = hash3(vec3(cell.yx, 7.0));
			glow += WINDOW_LIGHT * mix(0.5, 0.95, warmth) * pane * lit;
		}
		EMISSION = glow * night_glow;
	}
}
