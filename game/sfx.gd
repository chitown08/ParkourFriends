class_name Sfx
extends RefCounted
## Placeholder sound effects, made from code (beeps, swooshes and thuds), so
## there are no sound files to manage yet. Each is built the first time it's
## played. To swap one for a real recording later, load the file in _make().
##
##   Sfx.play(self, global_position, &"jump")   # a sound at a spot in the world
##   Sfx.play_ui(self, &"delivered")            # a sound everyone hears the same

const RATE := 22050 ## Samples per second.

static var _sounds := {}


## Plays `sound` at `position` in the world (`from` is any node in that world).
static func play(from: Node, position: Vector3, sound: StringName, volume_db := 0.0) -> void:
	var speaker := AudioStreamPlayer3D.new()
	speaker.stream = _stream(sound)
	speaker.volume_db = volume_db
	speaker.unit_size = 8.0 # Loud enough a few buildings away.
	speaker.pitch_scale = randf_range(0.94, 1.06) # A little variety.
	_start(from, speaker)
	speaker.global_position = position


## Plays `sound` without a position (menus, team announcements).
static func play_ui(from: Node, sound: StringName, volume_db := 0.0) -> void:
	var speaker := AudioStreamPlayer.new()
	speaker.stream = _stream(sound)
	speaker.volume_db = volume_db
	_start(from, speaker)


static func _start(from: Node, speaker: Node) -> void:
	if not from.is_inside_tree():
		speaker.free()
		return
	from.get_viewport().add_child(speaker)
	speaker.play()
	var length: float = speaker.stream.get_length()
	from.get_tree().create_timer(length + 0.2).timeout.connect(speaker.queue_free)


static func _stream(sound: StringName) -> AudioStreamWAV:
	if not _sounds.has(sound):
		_sounds[sound] = _make(sound)
	return _sounds[sound]


static func _make(sound: StringName) -> AudioStreamWAV:
	var samples: PackedFloat32Array
	match sound:
		&"jump":
			samples = _sweep(0.12, 280.0, 560.0, 0.4)
		&"leap":
			samples = _mix(_sweep(0.25, 180.0, 760.0, 0.4), _noise(0.3, 0.25, 0.35, true))
		&"land":
			samples = _mix(_sweep(0.12, 140.0, 45.0, 0.9), _noise(0.08, 0.4, 0.3, false))
		&"swing":
			samples = _noise(0.2, 0.15, 0.5, true)
		&"whack":
			samples = _mix(_noise(0.1, 0.9, 0.9, false), _sweep(0.16, 240.0, 80.0, 0.9))
		&"glide":
			samples = _noise(0.6, 0.08, 0.5, true)
		&"pickup":
			samples = _notes([660.0, 990.0], 0.06, 0.35)
		&"relic":
			samples = _notes([784.0, 988.0, 1175.0], 0.07, 0.35)
		&"delivered":
			samples = _notes([523.0, 659.0, 784.0, 1047.0], 0.1, 0.4)
		_:
			push_error("Sfx: no sound called %s" % sound)
			samples = PackedFloat32Array([0.0])
	return _to_stream(samples)


## A tone gliding from `from_hz` to `to_hz`, fading out.
static func _sweep(length: float, from_hz: float, to_hz: float, volume: float) -> PackedFloat32Array:
	var count := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * from_hz * pow(to_hz / from_hz, t) / RATE
		var envelope := minf(1.0, i / (0.005 * RATE)) * pow(1.0 - t, 2.0)
		samples[i] = sin(phase) * envelope * volume
	return samples


## A hiss: `brightness` 0..1 (low rumble to sharp crack). A `swell` fades in
## and out (a whoosh); otherwise it starts loud and dies away (a hit).
static func _noise(length: float, brightness: float, volume: float, swell: bool) -> PackedFloat32Array:
	var count := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), brightness)
		var envelope := sin(PI * t) if swell else pow(1.0 - t, 3.0)
		samples[i] = filtered * envelope * volume / sqrt(brightness)
	return samples


## A little tune: each note in turn, the last one ringing longer.
static func _notes(notes: Array[float], each: float, volume: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	for n in notes.size():
		var length := each * (3.0 if n == notes.size() - 1 else 1.0)
		var count := int(length * RATE)
		for i in count:
			var t := float(i) / count
			var time := float(i) / RATE
			var tone := sin(TAU * notes[n] * time) + 0.3 * sin(TAU * 2.0 * notes[n] * time)
			samples.append(tone * minf(1.0, i / (0.004 * RATE)) * pow(1.0 - t, 1.5) * volume)
	return samples


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var mixed := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		mixed[i] += other[i]
	return mixed


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
