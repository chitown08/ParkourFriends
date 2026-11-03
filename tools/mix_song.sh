#!/bin/bash
# Turns a song's stems from Suno (one WAV per instrument) into the few small
# layer files the game plays together (see game/playlist.gd, "layered songs"),
# in audio/music/<song>/:
#   base.ogg        drums, bass, keyboard, percussion: always playing
#   pack1.ogg       synth: comes in with one friend pack-running with you
#   pack2.ogg       brass: with two
#   extra-*.ogg     everything else, one each (strings, woodwinds, vocals,
#                   other with guitar...): a couple picked each time the song plays, and
#                   all of them with three friends
# A stem goes in the first layer whose instruments its name mentions (so
# "1 Drums.wav" -> base); anything not listed becomes an extra of its own.
#
# Needs ffmpeg (not part of the project: see README.md). Run from the project folder:
#   bash tools/mix_song.sh "audio/stems/Rooftop Test Music" rooftop_test
set -e

STEMS="$1"
SONG="$2"
if [ -z "$STEMS" ] || [ -z "$SONG" ]; then
	echo "Usage: bash tools/mix_song.sh <folder of stem WAVs> <song name, e.g. rooftop_test>"
	exit 1
fi
FFMPEG="${FFMPEG:-$LOCALAPPDATA/ParkourFriendsTools/ffmpeg/bin/ffmpeg.exe}"
OUT="audio/music/$SONG"
QUALITY=5 # Ogg Vorbis quality, 0-10 (5 is about 160 kbit/s).

declare -A LAYER_OF=(
	[drums]=base [bass]=base [keyboard]=base [percussion]=base
	[synth]=pack1
	[brass]=pack2
	[guitar]=extra-other [other]=extra-other
)

mkdir -p "$OUT"
rm -f "$OUT"/*.ogg
declare -A FILES
for stem in "$STEMS"/*.wav; do
	name=$(basename "$stem" .wav | sed -E 's/^[0-9]+ *//' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
	layer=""
	for instrument in "${!LAYER_OF[@]}"; do
		if [[ "$name" == *"$instrument"* ]]; then
			layer=${LAYER_OF[$instrument]}
		fi
	done
	if [ -z "$layer" ]; then
		layer="extra-${name##*_}" # "lead_vocals" -> extra-vocals
	fi
	FILES[$layer]+="$stem"$'\n'
done

for layer in "${!FILES[@]}"; do
	inputs=()
	count=0
	while IFS= read -r stem; do
		[ -n "$stem" ] || continue
		inputs+=(-i "$stem")
		count=$((count + 1))
	done <<< "${FILES[$layer]}"
	if [ "$count" -gt 1 ]; then
		mix=(-filter_complex "amix=inputs=$count:normalize=0:duration=longest")
	else
		mix=()
	fi
	# (Summed as they are, so together the layers sound like the full song.)
	"$FFMPEG" -hide_banner -loglevel error -y "${inputs[@]}" "${mix[@]}" -c:a libvorbis -q:a $QUALITY "$OUT/$layer.ogg"
	echo "$layer.ogg <- $count stem(s)"
done
du -sh "$OUT"
