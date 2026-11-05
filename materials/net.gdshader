// Rope netting: a mesh of rainbow cords with holes between (see-through),
// in world space like the grid, so any size of net looks the same.
shader_type spatial;
render_mode cull_disabled;

uniform float mesh_size = 0.5; // Metres between cords.
uniform float cord = 0.06; // How thick a cord is (metres).
uniform float rainbow_length = 6.0; // Metres for the colours to go all the way round.

varying vec3 world_pos;
varying vec3 world_normal;

vec3 hue(float h) {
	vec3 k = abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return clamp(k - 1.0, 0.0, 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 uv = n.y >= max(n.x, n.z) ? world_pos.xz : (n.x >= n.z ? world_pos.zy : world_pos.xy);
	// Diagonal cords (a diamond mesh, like a cargo net).
	vec2 diag = vec2(uv.x + uv.y, uv.x - uv.y) * 0.7071;
	vec2 to_cord = abs(fract(diag / mesh_size + 0.5) - 0.5) * mesh_size;
	float d = min(to_cord.x, to_cord.y);
	float aa = fwidth(d);
	float on_cord = 1.0 - smoothstep(cord - aa, cord + aa, d);
	// Far away the holes blur: fill in toward a solid sheet.
	on_cord = max(on_cord, smoothstep(0.02, 0.1, aa) * 0.7);
	ALBEDO = mix(vec3(0.9), hue((uv.x + uv.y) / rainbow_length), 0.85);
	ALPHA = on_cord;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
}
