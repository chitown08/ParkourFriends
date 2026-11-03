class_name Playlist
extends RefCounted
## The background music: every track in audio/music/ (a file, or a folder
## holding a layered song: see LayeredSong), shuffled. Each plays
## once before any plays again, and a new round never starts with the track
## that just finished. To add music, copy the files (.mp3, .ogg or .wav) into
## audio/music/ and open the editor once, so Godot imports them.

const DIR := "res://audio/music/"
const KINDS: Array[String] = ["mp3", "ogg", "wav"]

## Every track (its res:// path).
var tracks: Array[String] = []
## The track playing (or last played).
var current := ""
var _left: Array[String] = []


## A playlist of `paths` (by default, everything in DIR).
func _init(paths: Array[String] = []) -> void:
	tracks = paths if not paths.is_empty() else find_tracks()


## Every music file in DIR. (ResourceLoader lists them the same way in the
## editor and in the exported game.)
static func find_tracks() -> Array[String]:
	var found: Array[String] = []
	for file in ResourceLoader.list_directory(DIR):
		if file.get_extension().to_lower() in KINDS or LayeredSong.is_layered(DIR + file):
			found.append(DIR + file)
	found.sort()
	return found


## Marks `path` as playing now (e.g. a world's own song to start with), so it
## isn't picked again this round.
func start_with(path: String) -> void:
	if _left.is_empty():
		_left = tracks.duplicate()
		_left.shuffle()
	current = path
	_left.erase(path)


## The next track to play ("" if there are none).
func next() -> String:
	if tracks.is_empty():
		return ""
	if _left.is_empty():
		_left = tracks.duplicate()
		_left.shuffle()
		# Not the one that just finished, straight away again.
		if _left.size() > 1 and _left[0] == current:
			_left.append(_left.pop_front())
	current = _left.pop_front()
	return current
