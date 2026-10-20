extends Node2D

const TICK_SOUND: AudioStream = preload("res://assets/audio/sfx/MNT_YTK_ui_slider_change.wav")
## Passes arrive far faster than sound can usefully play, so ticks are rate-limited (scoring isn't).
const TICK_MIN_INTERVAL_MS := 35
const TICK_VOLUME_DB := -12.0
## Pitch rises by this much per tick played in the current spin, up to TICK_PITCH_MAX.
const TICK_PITCH_STEP := 0.004
const TICK_PITCH_MAX := 1.5

var _last_tick_ms := 0
var _ticks_this_spin := 0


func _ready() -> void:
	$WheelViewportOutput.position = get_viewport_rect().size / 2
	$SubViewport/RouletteWheel.spin_finished.connect(_on_wheel_spin_finished)
	$SubViewport/RouletteWheel.pocket_passed.connect(_on_wheel_pocket_passed)

func _on_wheel_pocket_passed(_index: int, segment: Dictionary) -> void:
	$HUD.show_pass(segment)

	var now := Time.get_ticks_msec()
	if now - _last_tick_ms >= TICK_MIN_INTERVAL_MS:
		_last_tick_ms = now
		var pitch := minf(0.5 + _ticks_this_spin * TICK_PITCH_STEP, TICK_PITCH_MAX)
		_ticks_this_spin += 1
		Audio.play_sfx(TICK_SOUND, TICK_VOLUME_DB, pitch * randf_range(0.98, 1.02))

func _on_wheel_spin_finished(index: int, segment: Dictionary) -> void:
	print("Landed on %s (%s) at index %d" % [segment["number"], segment["colour"], index])

func _on_spin_requested() -> void:
	var wheel := $SubViewport/RouletteWheel
	if not wheel.is_spinning:
		_ticks_this_spin = 0
	wheel.spin_wheel()
