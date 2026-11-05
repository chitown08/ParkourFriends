class_name TimeOfDay
## Times of day: each sets the sky (materials/sky.gdshader), the sun's angle,
## colour and strength, the ambient light and the fog. The host picks one
## (Settings.time_of_day, in the pause menu) and everyone in the game sees it.
## At sunset and night the city's windows light up, and the coloured things
## glow a little so they stay easy to read (the night_glow shader global:
## see materials/grid.gdshader).

const SKY_SHADER := preload("res://materials/sky.gdshader")
## How much the fog covers the sky (it would hide the sky's colours).
const FOG_ON_SKY := 0.15
## How much the city glows now (the night_glow shader global: kept here too,
## as Godot can't always read it back).
static var night_glow := 0.0

## In the order the menu lists them.
const NAMES: Array[String] = ["day", "morning", "golden_hour", "sunset", "night"]
const LABELS := {"day": "Day", "morning": "Morning", "golden_hour": "Golden hour", "sunset": "Sunset", "night": "Night"}

## Each: the sun (degrees up from the horizon, and round from north), its
## light (colour, strength); the sky (top, horizon, ground; the glow round the
## sun and how strong; the sun's disc colour and size; clouds: how much,
## lit colour, shade; stars); the ambient light (colour, strength); the fog
## (colour, density); and how much the city glows (0..1).
const PRESETS := {
	"day": {"sun": Vector2(50, -30), "light": Color(1.0, 0.97, 0.9), "energy": 1.0,
			"top": Color(0.22, 0.46, 0.85), "horizon": Color(0.78, 0.86, 0.95), "ground": Color(0.5, 0.52, 0.56),
			"glow": Color(1.0, 0.95, 0.85), "glow_strength": 0.15, "disc": Color(1.0, 0.98, 0.92), "disc_size": 0.9995,
			"clouds": 0.42, "cloud": Color(1.0, 1.0, 1.0), "cloud_shade": Color(0.78, 0.82, 0.9), "stars": 0.0,
			"ambient": Color(0.85, 0.88, 0.92), "ambient_energy": 0.55, "fog": Color(0.82, 0.88, 0.95), "fog_density": 0.001, "night_glow": 0.0},
	"morning": {"sun": Vector2(18, 70), "light": Color(1.0, 0.9, 0.76), "energy": 0.9,
			"top": Color(0.35, 0.55, 0.85), "horizon": Color(0.96, 0.86, 0.76), "ground": Color(0.55, 0.5, 0.5),
			"glow": Color(1.0, 0.78, 0.58), "glow_strength": 0.35, "disc": Color(1.0, 0.95, 0.82), "disc_size": 0.9994,
			"clouds": 0.35, "cloud": Color(1.0, 0.93, 0.86), "cloud_shade": Color(0.74, 0.72, 0.8), "stars": 0.0,
			"ambient": Color(0.86, 0.83, 0.8), "ambient_energy": 0.5, "fog": Color(0.93, 0.87, 0.81), "fog_density": 0.0007, "night_glow": 0.0},
	"golden_hour": {"sun": Vector2(9, -110), "light": Color(1.0, 0.78, 0.46), "energy": 1.1,
			"top": Color(0.24, 0.4, 0.75), "horizon": Color(1.0, 0.76, 0.46), "ground": Color(0.5, 0.42, 0.38),
			"glow": Color(1.0, 0.6, 0.26), "glow_strength": 0.55, "disc": Color(1.0, 0.86, 0.6), "disc_size": 0.9993,
			"clouds": 0.5, "cloud": Color(1.0, 0.82, 0.6), "cloud_shade": Color(0.7, 0.52, 0.52), "stars": 0.0,
			"ambient": Color(0.9, 0.76, 0.64), "ambient_energy": 0.42, "fog": Color(1.0, 0.82, 0.64), "fog_density": 0.0005, "night_glow": 0.0},
	"sunset": {"sun": Vector2(2, -100), "light": Color(1.0, 0.52, 0.28), "energy": 0.65,
			"top": Color(0.17, 0.19, 0.44), "horizon": Color(1.0, 0.46, 0.3), "ground": Color(0.3, 0.25, 0.3),
			"glow": Color(1.0, 0.36, 0.2), "glow_strength": 0.75, "disc": Color(1.0, 0.68, 0.42), "disc_size": 0.9992,
			"clouds": 0.55, "cloud": Color(1.0, 0.56, 0.46), "cloud_shade": Color(0.42, 0.3, 0.45), "stars": 0.05,
			"ambient": Color(0.62, 0.47, 0.56), "ambient_energy": 0.42, "fog": Color(0.86, 0.5, 0.45), "fog_density": 0.002, "night_glow": 0.35},
	"night": {"sun": Vector2(40, 150), "light": Color(0.6, 0.7, 1.0), "energy": 0.25,
			"top": Color(0.02, 0.03, 0.08), "horizon": Color(0.08, 0.1, 0.2), "ground": Color(0.03, 0.03, 0.05),
			"glow": Color(0.4, 0.5, 0.8), "glow_strength": 0.15, "disc": Color(0.92, 0.94, 1.0), "disc_size": 0.9993,
			"clouds": 0.3, "cloud": Color(0.25, 0.28, 0.38), "cloud_shade": Color(0.12, 0.13, 0.2), "stars": 1.0,
			"ambient": Color(0.38, 0.43, 0.62), "ambient_energy": 0.4, "fog": Color(0.08, 0.1, 0.18), "fog_density": 0.002, "night_glow": 1.0},
}


## Sets `level`'s sky, sun, light and fog for `time` (one of NAMES; anything
## else is "day"), and how much the city glows.
static func apply(level: Node, time: String) -> void:
	var preset: Dictionary = PRESETS.get(time, PRESETS["day"])
	night_glow = preset.night_glow
	RenderingServer.global_shader_parameter_set(&"night_glow", night_glow)
	if level == null:
		return
	var environments := level.find_children("*", "WorldEnvironment", true, false)
	if not environments.is_empty():
		var environment: Environment = (environments[0] as WorldEnvironment).environment
		var sky_material := _sky_material(environment)
		sky_material.set_shader_parameter(&"top_color", preset.top)
		sky_material.set_shader_parameter(&"horizon_color", preset.horizon)
		sky_material.set_shader_parameter(&"ground_color", preset.ground)
		sky_material.set_shader_parameter(&"glow_color", preset.glow)
		sky_material.set_shader_parameter(&"glow_strength", preset.glow_strength)
		sky_material.set_shader_parameter(&"sun_color", preset.disc)
		sky_material.set_shader_parameter(&"sun_size", preset.disc_size)
		sky_material.set_shader_parameter(&"cloud_amount", preset.clouds)
		sky_material.set_shader_parameter(&"cloud_color", preset.cloud)
		sky_material.set_shader_parameter(&"cloud_shade", preset.cloud_shade)
		sky_material.set_shader_parameter(&"stars", preset.stars)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = preset.ambient
		environment.ambient_light_energy = preset.ambient_energy
		environment.fog_light_color = preset.fog
		environment.fog_density = preset.fog_density
		environment.fog_sky_affect = FOG_ON_SKY
	var lights := level.find_children("*", "DirectionalLight3D", true, false)
	if not lights.is_empty():
		var sun := lights[0] as DirectionalLight3D
		sun.global_basis = Basis.looking_at(-sun_direction(time))
		sun.light_color = preset.light
		sun.light_energy = preset.energy


## The way to the sun (or moon) at `time`, from anywhere (a unit vector).
static func sun_direction(time: String) -> Vector3:
	var angles: Vector2 = (PRESETS.get(time, PRESETS["day"]) as Dictionary).sun
	var up := deg_to_rad(angles.x)
	var round := deg_to_rad(angles.y)
	return Vector3(cos(up) * sin(round), sin(up), -cos(up) * cos(round))


## `environment`'s sky drawn with the sky shader (made so the first time).
static func _sky_material(environment: Environment) -> ShaderMaterial:
	if environment.sky == null:
		environment.sky = Sky.new()
	environment.background_mode = Environment.BG_SKY
	var material := environment.sky.sky_material as ShaderMaterial
	if material == null or material.shader != SKY_SHADER:
		material = ShaderMaterial.new()
		material.shader = SKY_SHADER
		material.set_shader_parameter(&"cloud_noise", _cloud_noise())
		environment.sky.sky_material = material
	return material


static var _noise_texture: NoiseTexture2D


## Soft, tiling noise for the clouds (made once).
static func _cloud_noise() -> NoiseTexture2D:
	if _noise_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.008
		noise.fractal_octaves = 5
		_noise_texture = NoiseTexture2D.new()
		_noise_texture.width = 512
		_noise_texture.height = 512
		_noise_texture.seamless = true
		_noise_texture.generate_mipmaps = true
		_noise_texture.noise = noise
	return _noise_texture
