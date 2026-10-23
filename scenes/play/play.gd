extends Node2D
## The play phase for one round: spin until the round's target is reached or the spins run out,
## then emit `finished` with {won, score}. Round progress lives in `run.current_round`, so a loaded
## save resumes part-way through.

signal finished(result: Dictionary)

const TICK_SOUND: AudioStream = preload("res://assets/audio/sfx/MNT_YTK_ui_slider_change.wav")
## Passes arrive far faster than sound can usefully play, so ticks are rate-limited (scoring isn't).
const TICK_MIN_INTERVAL_MS := 35
const TICK_VOLUME_DB := -12.0
## Pitch rises by this much per tick played in the current spin, up to TICK_PITCH_MAX.
const TICK_PITCH_STEP := 0.004
const TICK_PITCH_MAX := 1.5

enum State { WAITING, SPINNING, DONE }

var _run: RunState
var _step: RoundStep
var _state := State.WAITING
var _last_tick_ms := 0
var _ticks_this_spin := 0
var _chips := 0 # submitted for the spin in progress
var _bet: Bet # placed for the spin in progress
var _ctx: ScoreContext # live score of the spin in progress

@onready var _wheel := $SubViewport/RouletteWheel
@onready var _hud := $HUD
@onready var _cards: CardContainer = $CardContainer


## Called by the runner before the scene enters the tree.
func setup(run: RunState, step: RunStep) -> void:
	_run = run
	_step = step


# Dragging cards reorders the tickets, and ticket order is a mechanic.
func _on_cards_order_changed() -> void:
	_run.tickets = _cards.get_tickets()
	Game.save_run()
	_hud.show_round(_run, _step)


func _ready() -> void:
	# Running this scene on its own (F6) has no runner, so make a throwaway run and round.
	if _run == null:
		Game.new_run(randi(), false)
		_run = Game.run
		_step = RoundStep.new()
		_run.current_step = _step

	$WheelViewportOutput.position = get_viewport_rect().size / 2
	_wheel.rng = _run.rng
	_wheel.set_pockets(_run.pockets)
	_wheel.spin_finished.connect(_on_wheel_spin_finished)
	_wheel.pocket_passed.connect(_on_wheel_pocket_passed)

	if _run.current_round == null:
		_run.current_round = RoundState.new()
		_run.current_round.spins_left = Modifiers.spins_per_round(_run)
		Modifiers.notify(_run, &"round_started", [_run.current_round])
		Game.save_run()

	_cards.set_tickets(_run.tickets)
	_cards.order_changed.connect(_on_cards_order_changed)

	_hud.show_round(_run, _step)
	# A save made after the last spin resumes straight into the result.
	if _is_round_over():
		_finish()


func _on_spin_requested() -> void:
	if _state != State.WAITING:
		return
	_state = State.SPINNING
	_chips = _hud.get_chips()
	_bet = _hud.get_bet()
	_ctx = ScoreContext.new(_chips, _bet)
	_hud.set_inputs_editable(false)
	_ticks_this_spin = 0
	Modifiers.notify(_run, &"spin_started")
	_wheel.spin_wheel()


func _on_wheel_pocket_passed(_index: int, pocket: Pocket) -> void:
	Modifiers.notify(_run, &"pocket_passed", [pocket, _ctx])
	_hud.show_equation(_ctx.points, _ctx.mult)
	_hud.show_money(_run)
	_hud.show_pass(pocket)

	var now := Time.get_ticks_msec()
	if now - _last_tick_ms >= TICK_MIN_INTERVAL_MS:
		_last_tick_ms = now
		var pitch := minf(0.5 + _ticks_this_spin * TICK_PITCH_STEP, TICK_PITCH_MAX)
		_ticks_this_spin += 1
		Audio.play_sfx(TICK_SOUND, TICK_VOLUME_DB, pitch * randf_range(0.98, 1.02))


func _on_wheel_spin_finished(_index: int, pocket: Pocket) -> void:
	Modifiers.notify(_run, &"pocket_landed", [pocket])
	var ctx := Modifiers.score(_run, _ctx, pocket)
	var progress := _run.current_round
	progress.score += ctx.total()
	progress.spins_left -= 1
	Modifiers.notify(_run, &"spin_finished", [pocket])

	_hud.show_score(ctx)
	_hud.show_round(_run, _step)
	Game.save_run()

	if _is_round_over():
		_finish()
	else:
		_hud.set_inputs_editable(true)
		_state = State.WAITING


func _is_round_over() -> bool:
	var progress := _run.current_round
	return progress.score >= _step.target_score or progress.spins_left <= 0


func _finish() -> void:
	_state = State.DONE
	var progress := _run.current_round
	var won := progress.score >= _step.target_score
	Modifiers.notify(_run, &"round_finished", [progress, won])
	_hud.show_result(won)
	await _hud.continue_requested
	finished.emit({"won": won, "score": progress.score})
