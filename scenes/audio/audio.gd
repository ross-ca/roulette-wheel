extends Node
## Autoload ("Audio"): a small pool of players for overlapping one-shot sound effects.

const VOICES := 8

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_voices.append(player)


## Plays `stream` on a free voice, or steals the oldest one if all are busy.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player: AudioStreamPlayer = _voices[_next_voice]
	for voice in _voices:
		if not voice.playing:
			player = voice
			break
	_next_voice = (_voices.find(player) + 1) % VOICES

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
