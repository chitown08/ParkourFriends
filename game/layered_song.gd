class_name LayeredSong
extends RefCounted
## A song in layers, that swells as your pack grows: a folder in audio/music/
## made by tools/mix_song.sh from the song's stems. All its layers play
## together, in step; which you hear depends on how many friends are
## pack-running with you:
##   base.ogg     always (alone, a little muffled: see main.gd)
##   pack1.ogg    with one friend (and the muffling lifts)
##   pack2.ogg    with two
##   extra-*.ogg  with three, all of them; otherwise a couple, picked each
##                time the song starts, so it's a little different every time
## Layers fade in and out over FADE_TIME seconds.

const FADE_TIME := 1.5
## How many extras play anyway (picked at random as the song starts).
const EXTRAS_PICKED := Vector2i(1, 2)
## Quieter than this (decibels) counts as off.
const SILENT_DB := -80.0

## What plays all the layers together.
var stream := AudioStreamSynchronized.new()
## Each layer's name ("base", "pack1", "extra-strings"...), in stream order.
var layers: Array[String] = []
## The extras picked to play this time.
var picked: Array[String] = []
var _volumes: Array[float] = []


## The layers in `folder` (a res:// path ending in "/").
func _init(folder: String) -> void:
	for file in ResourceLoader.list_directory(folder):
		if file.get_extension() in ["ogg", "wav", "mp3"]:
			layers.append(file.get_basename())
	layers.sort()
	stream.stream_count = layers.size()
	for i in layers.size():
		var path := folder + layers[i] + ".ogg"
		if not ResourceLoader.exists(path):
			path = folder + layers[i] + (".wav" if ResourceLoader.exists(folder + layers[i] + ".wav") else ".mp3")
		stream.set_sync_stream(i, load(path))
		_volumes.append(0.0)
	var extras := layers.filter(func(layer: String) -> bool: return layer.begins_with("extra-"))
	extras.shuffle()
	picked.assign(extras.slice(0, randi_range(EXTRAS_PICKED.x, EXTRAS_PICKED.y)))
	set_pack(0, 0.0)


## True if `path` is a layered song (a folder with a base layer in it).
static func is_layered(path: String) -> bool:
	return path.ends_with("/") and (ResourceLoader.exists(path + "base.ogg") or ResourceLoader.exists(path + "base.wav"))


## How loud each layer should be (0..1) with `pack` friends running with you.
func wanted_volume(layer: String, pack: int) -> float:
	if layer == "base":
		return 1.0
	if layer.begins_with("pack"):
		return 1.0 if pack >= layer.trim_prefix("pack").to_int() else 0.0
	if layer.begins_with("extra-"):
		return 1.0 if pack >= 3 or layer in picked else 0.0
	return 1.0 # (Anything else: always.)


## Eases the layers toward what `pack` friends should hear, over `delta`
## seconds (0: straight there).
func set_pack(pack: int, delta: float) -> void:
	var step := 1.0 if delta <= 0.0 else delta / FADE_TIME
	for i in layers.size():
		_volumes[i] = move_toward(_volumes[i], wanted_volume(layers[i], pack), step)
		stream.set_sync_stream_volume(i, maxf(linear_to_db(_volumes[i]), SILENT_DB) if _volumes[i] > 0.001 else SILENT_DB)


## How loud layer `layer` is right now (0..1, for tests).
func volume(layer: String) -> float:
	return _volumes[layers.find(layer)]
