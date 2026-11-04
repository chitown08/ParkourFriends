// The light trails' shared part (see light_trail.gdshader).
uniform vec4 color : source_color = vec4(0.2, 0.55, 0.95, 1.0);
// Half its width (metres) up close...
uniform float near_width = 0.12;
// ...and at least this much of the view (half width, per metre away).
uniform float screen_width = 0.006;
// Faint closer than this (metres from the camera), full from `full_from`.
uniform float faint_within = 3.0;
uniform float full_from = 25.0;
// How strong it shows (the see-through-walls pass is fainter).
uniform float strength = 1.0;

varying float near;

void vertex() {
	// NORMAL carries the way along the trail; UV.x which edge (-1 or 1).
	vec3 at = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 along = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 side = cross(along, normalize(at));
	side = length(side) > 0.0001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float distance_away = length(at);
	at += side * UV.x * max(near_width, distance_away * screen_width);
	near = smoothstep(faint_within, full_from, distance_away);
	POSITION = PROJECTION_MATRIX * vec4(at, 1.0);
}

void fragment() {
	// Full colour down the middle, darker at the edges (it stands out against
	// the pale city and the sky).
	float edge = abs(UV.x);
	ALBEDO = mix(color.rgb, color.rgb * 0.45, smoothstep(0.55, 0.9, edge));
	ALPHA = COLOR.a * (0.15 + 0.85 * near) * strength;
}
