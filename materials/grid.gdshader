// Grey-box material: a flat color with a 1 meter grid drawn on it in world
// space, so you can judge distances and heights at a glance.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.6);
uniform vec3 line_color : source_color = vec3(0.4);
uniform float grid_size = 1.0;
uniform float line_width = 0.025;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Project the grid onto whichever axis the surface mostly faces.
	vec3 n = abs(world_normal);
	vec2 uv = n.y >= max(n.x, n.z) ? world_pos.xz : (n.x >= n.z ? world_pos.zy : world_pos.xy);
	vec2 to_line = abs(fract(uv / grid_size + 0.5) - 0.5) * grid_size;
	float d = min(to_line.x, to_line.y);
	float aa = fwidth(d);
	float line = 1.0 - smoothstep(line_width - aa, line_width + aa, d);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.85;
}
