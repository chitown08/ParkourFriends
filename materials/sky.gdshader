// The sky (see game/time_of_day.gd, which sets these for each time of day):
// a gradient from the horizon up, a warm glow round the sun, the sun's disc
// (or at night the moon's), soft stylized clouds drifting by, and stars.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.22, 0.46, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.86, 0.95);
uniform vec3 ground_color : source_color = vec3(0.5, 0.52, 0.56);
// The glow round the sun, along the horizon too (a sunset's band).
uniform vec3 glow_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float glow_strength = 0.3;
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.9);
// The sun's (or moon's) size, as the cosine of its angular radius.
uniform float sun_size = 0.9995;
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.78, 0.82, 0.9);
uniform float cloud_amount = 0.45;
uniform float stars = 0.0;
// Soft noise for the clouds (made by game/time_of_day.gd).
uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float clouds(vec2 p) {
	return texture(cloud_noise, p * 0.11).r * 0.75 + texture(cloud_noise, p * 0.31 + vec2(0.37, 0.71)).r * 0.25;
}

void sky() {
	vec3 dir = EYEDIR;
	float up = dir.y;
	vec3 sun = LIGHT0_DIRECTION;
	// The gradient: horizon to top above, horizon to ground below.
	vec3 color = up >= 0.0 ? mix(horizon_color, top_color, pow(up, 0.6)) : mix(horizon_color, ground_color, pow(-up, 0.4));
	// The glow: round the sun, and along the horizon toward it.
	float toward = max(dot(dir, sun), 0.0);
	float horizon_band = (1.0 - abs(up)) * max(dot(normalize(vec3(dir.x, 0.0, dir.z) + vec3(0.0001)), normalize(vec3(sun.x, 0.0, sun.z) + vec3(0.0001))), 0.0);
	color = mix(color, glow_color, clamp(glow_strength * (pow(toward, 6.0) + 0.6 * pow(horizon_band, 3.0)), 0.0, 1.0));
	if (up > 0.0) {
		// Stars, faint near the horizon.
		vec2 cell = floor(dir.xz / max(up, 0.05) * 90.0 + dir.xz * 400.0);
		float star = step(0.9984, hash(cell)) * stars * smoothstep(0.0, 0.25, up);
		color += vec3(star);
		// Clouds: a layer overhead, seen in perspective, drifting.
		vec2 uv = dir.xz / (up + 0.15) * 0.9 + vec2(TIME * 0.004, TIME * 0.0015);
		float c = clouds(uv);
		float cover = smoothstep(1.0 - cloud_amount - 0.05, 1.0 - cloud_amount + 0.2, c);
		float shade = smoothstep(-0.05, 0.3, c - (1.0 - cloud_amount));
		vec3 cloud = mix(cloud_shade, cloud_color, shade) + glow_color * glow_strength * pow(toward, 3.0) * 0.6;
		color = mix(color, cloud, cover * smoothstep(0.0, 0.12, up));
	}
	// The sun's disc (at night, the moon's: the light is moonlight).
	float disc = smoothstep(sun_size - 0.00015, sun_size + 0.00015, dot(dir, sun));
	color = mix(color, sun_color, disc);
	COLOR = color;
}
