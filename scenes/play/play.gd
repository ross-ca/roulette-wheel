extends Control
## The play phase for one round: spin until the round's target is reached or the spins run out,
## then emit `finished` with {won, score}. Round progress lives in `run.current_round`, so a loaded
## save resumes part-way through.
##
## The round has two views that slide sideways between each other: betting (place chips on the
## table) and the wheel (spin it and watch the bets score). The views only display and report input;
## the rules are all here. The ticket strip is shared, and glides between the views' ticket slots.

signal finished(result: Dictionary)

const TICK_SOUND: AudioStream = preload("res://assets/audio/sfx/MNT_YTK_ui_slider_change.wav")
## Passes arrive far faster than sound can usefully play, so ticks are rate-limited (scoring isn't).
const TICK_MIN_INTERVAL_MS := 35
const TICK_VOLUME_DB := -12.0
## Pitch rises by this much per tick played in the current spin, up to TICK_PITCH_MAX.
const TICK_PITCH_STEP := 0.004
const TICK_PITCH_MAX := 1.5

## The chips offered in the betting view. Placeholder until chips are tied to money.
const CHIP_VALUES: Array[int] = [1, 5, 10, 25, 100]
## Seconds a slide between the views takes.
const SLIDE_DURATION := 0.35

enum State { WAITING, SPINNING, DONE }
enum View { BETTING, WHEEL }

var _run: RunState
var _step: RoundStep
var _state := State.WAITING
var _last_tick_ms := 0
var _ticks_this_spin := 0
var _spin: SpinContext # live score of the spin in progress
## 0 shows the betting view, 1 the wheel view, and values between are part-way through a slide.
var _view_position := 0.0
var _slide: Tween

@onready var _wheel := $SubViewport/RouletteWheel
@onready var _views: Control = $Views
@onready var _betting: BettingView = $Views/BettingView
@onready var _wheel_view: WheelView = $Views/WheelView
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


func _ready() -> void:
	# Running this scene on its own (F6) has no runner, so make a throwaway run and round.
	if _run == null:
		Game.new_run(randi(), false)
		_run = Game.run
		_step = RoundStep.new()
		_run.current_step = _step

	_wheel_view.set_wheel_texture($SubViewport.get_texture())
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

	_betting.set_chip_values(CHIP_VALUES)
	_betting.show_pockets(_run.pockets)
	_show_round()
	_show_bets()
	_place_views()
	# A save made after the last spin resumes straight into the result.
	if _is_round_over():
		_finish()


func _process(_delta: float) -> void:
	_place_views()


func _on_wheel_requested() -> void:
	_show_view(View.WHEEL)


func _on_betting_requested() -> void:
	if _state != State.SPINNING:
		_show_view(View.BETTING)


# Slides to `view` from wherever the views are now, so switching again mid-slide turns it round.
func _show_view(view: View) -> void:
	if _slide:
		_slide.kill()
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_property(self, "_view_position", float(view), SLIDE_DURATION)


# Lays the views side by side, shifted by how far the slide has got, and puts the ticket strip
# the same fraction of the way from the betting view's slot to the wheel view's. Runs every frame,
# so it also follows window resizes.
func _place_views() -> void:
	var width := _views.size.x
	for view: Control in [_betting, _wheel_view]:
		view.size = _views.size
	_betting.position.x = -_view_position * width
	_wheel_view.position.x = (1.0 - _view_position) * width

	var from := _betting.ticket_slot.get_global_rect()
	var to := _wheel_view.ticket_slot.get_global_rect()
	_cards.global_position = from.position.lerp(to.position, _view_position)
	_cards.size = from.size.lerp(to.size, _view_position)


# A chip dropped on a spot that already has a bet joins its chips.
func _on_bet_placed(bet: Bet, chip: PlacedChip) -> void:
	if _state != State.WAITING:
		return
	var placed := _find_bet(bet)
	if placed == null:
		placed = PlacedBet.of(bet.duplicate()) # the table keeps its own spot's bet
		_run.current_round.bets.append(placed)
	placed.chips.append(chip)
	_show_bets()
	Game.save_run()


func _on_bet_cleared(bet: Bet) -> void:
	if _state != State.WAITING:
		return
	var placed := _find_bet(bet)
	if placed:
		_run.current_round.bets.erase(placed)
		_show_bets()
		Game.save_run()


func _find_bet(bet: Bet) -> PlacedBet:
	for placed in _run.current_round.bets:
		if placed.bet.key() == bet.key():
			return placed
	return null


func _on_spin_requested() -> void:
	if _state != State.WAITING or _run.current_round.bets.is_empty():
		return
	_state = State.SPINNING
	_spin = SpinContext.new(_run.current_round.bets)
	_betting.set_editable(false)
	_wheel_view.set_spinning(true)
	_ticks_this_spin = 0
	Modifiers.notify(_run, &"spin_started")
	_wheel.spin_wheel()


func _on_wheel_pocket_passed(_index: int, pocket: Pocket) -> void:
	Modifiers.notify(_run, &"pocket_passed", [pocket, _spin])
	_wheel_view.show_spin(_spin)
	_betting.show_round(_run, _step) # pass tickets can pay out mid-spin
	_hud.show_pass(pocket)

	var now := Time.get_ticks_msec()
	if now - _last_tick_ms >= TICK_MIN_INTERVAL_MS:
		_last_tick_ms = now
		var pitch := minf(0.5 + _ticks_this_spin * TICK_PITCH_STEP, TICK_PITCH_MAX)
		_ticks_this_spin += 1
		Audio.play_sfx(TICK_SOUND, TICK_VOLUME_DB, pitch * randf_range(0.98, 1.02))


func _on_wheel_spin_finished(_index: int, pocket: Pocket) -> void:
	Modifiers.notify(_run, &"pocket_landed", [pocket])
	Modifiers.score(_run, _spin, pocket)
	var progress := _run.current_round
	progress.score += _spin.total()
	progress.spins_left -= 1
	progress.bets.clear() # the spin uses its bets up
	Modifiers.notify(_run, &"spin_finished", [pocket])

	# The rows keep showing this spin's result until the next bet is placed.
	_wheel_view.show_result(_spin)
	_betting.show_bets(progress.bets)
	_wheel_view.set_spinning(false)
	_state = State.WAITING
	_show_round()
	Game.save_run()

	if _is_round_over():
		_finish()
	else:
		_betting.set_editable(true)


# Round info in both views.
func _show_round() -> void:
	_betting.show_round(_run, _step)
	_wheel_view.set_can_spin(_state == State.WAITING and not _run.current_round.bets.is_empty())


# The bets on the table, in both views.
func _show_bets() -> void:
	var bets := _run.current_round.bets
	_betting.show_bets(bets)
	_wheel_view.show_bets(bets)
	_show_round()


func _is_round_over() -> bool:
	var progress := _run.current_round
	return progress.score >= _step.target_score or progress.spins_left <= 0


func _finish() -> void:
	_state = State.DONE
	_betting.set_editable(false)
	_wheel_view.set_can_spin(false)
	var progress := _run.current_round
	var won := progress.score >= _step.target_score
	Modifiers.notify(_run, &"round_finished", [progress, won])
	_hud.show_result(won)
	await _hud.continue_requested
	finished.emit({"won": won, "score": progress.score})
