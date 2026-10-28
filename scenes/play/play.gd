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
var _selling := false # a ticket's card is dissolving
var _selected: Consumable # picked, waiting for the player to pick its targets on the table
var _picked: Array[Pocket] = [] # the targets chosen so far for _selected
var _using := false # a used consumable's card is dissolving

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
	_run.tickets.assign(_cards.get_items())
	Game.save_run()


# Right-clicking a ticket sells it for half its price. Not mid-spin: tickets are scoring then. The
# ticket stays in the run (and spinning is blocked) until its card has finished dissolving.
func _on_cards_item_right_clicked(item: Modifier) -> void:
	if _state == State.SPINNING or _selling or not item is Ticket:
		return
	_selling = true
	await _cards.remove_item(item)
	_run.tickets.erase(item)
	_run.money += int(item.price * 0.5)
	_show_round()
	Game.save_run()
	_selling = false


func _ready() -> void:
	# Running this scene on its own (F6) has no runner, so make a throwaway run and round.
	if _run == null:
		Game.new_run(randi(), false)
		_run = Game.run
		_step = RoundStep.new()
		_run.current_step = _step

	_wheel_view.set_wheel($SubViewport, $SubViewport/SpinButton, _wheel.hub_radius())
	_wheel.rng = _run.rng
	_wheel.set_pockets(_run.pockets)
	_wheel.spin_finished.connect(_on_wheel_spin_finished)
	_wheel.pocket_passed.connect(_on_wheel_pocket_passed)

	if _run.current_round == null:
		_run.current_round = RoundState.new()
		_run.current_round.spins_left = Modifiers.spins_per_round(_run)
		Modifiers.notify(_run, &"round_started", [_run.current_round])
		Game.save_run()

	_cards.set_items(_run.tickets)
	_cards.order_changed.connect(_on_cards_order_changed)
	_cards.item_right_clicked.connect(_on_cards_item_right_clicked)

	_betting.set_chip_values(CHIP_VALUES)
	_betting.show_pockets(_run.pockets)
	_betting.show_consumables(_run.consumables)
	_betting.consumable_clicked.connect(_on_consumable_clicked)
	_betting.consumables_reordered.connect(_on_consumables_reordered)
	_betting.spot_clicked.connect(_on_spot_clicked)
	_wheel_view.show_pockets(_run.pockets)
	_show_round()
	_show_bets()
	_place_views()
	# A save made after the last spin resumes straight into the result.
	if _is_round_over():
		_finish()


func _process(_delta: float) -> void:
	_place_views()


# Clicking a consumable picks it (or puts it down again); the next valid tile clicked is its target.
func _on_consumable_clicked(item: Consumable) -> void:
	if _state != State.WAITING or _using:
		return
	_selected = null if _selected == item else item
	_picked.clear()
	_betting.select_consumable(_selected)


func _on_consumables_reordered() -> void:
	_run.consumables.assign(_betting.get_consumables())
	Game.save_run()


# Only number tiles are targets for now, as they stand for one pocket each. A consumable that
# can't use the pocket leaves itself selected.
func _on_spot_clicked(bet: Bet) -> void:
	if _selected == null or _state != State.WAITING or _using or not bet is NumberBet:
		return
	var pocket := _find_pocket(bet.number)
	if pocket == null or not _selected.can_target(_run, pocket, _picked):
		return
	_picked.append(pocket)
	if _picked.size() < _selected.target_count():
		return # waiting for the rest of its targets
	_using = true
	var item := _selected
	var pockets := _picked.duplicate()
	_selected = null
	_picked.clear()
	_betting.select_consumable(null)
	item.use(_run, pockets)
	Modifiers.notify(_run, &"consumable_used", [item, pockets])
	_run.consumables.erase(item)
	# The wheel redraws itself as the pocket changes; the table and the rows' badges need telling.
	_betting.show_pockets(_run.pockets)
	_wheel_view.show_pockets(_run.pockets)
	if not _run.current_round.bets.is_empty():
		_wheel_view.show_bets(_run.current_round.bets)
	Game.save_run()
	await _betting.remove_consumable(item)
	_using = false


func _find_pocket(number: int) -> Pocket:
	for pocket in _run.pockets:
		if pocket.number == number:
			return pocket
	return null


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
	if _state != State.WAITING or _selling or _using or _run.current_round.bets.is_empty():
		return
	_state = State.SPINNING
	_selected = null
	_picked.clear()
	_betting.select_consumable(null)
	_spin =SpinContext.new(_run.current_round.bets)
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

	_betting.show_bets(progress.bets)
	Game.save_run()

	# The rows reveal each bet's result and keep showing it until the next bet is placed. The wheel
	# view stays locked (still SPINNING) until the reveal has played.
	await _wheel_view.show_result(_spin)
	_wheel_view.set_spinning(false)
	_state = State.WAITING
	_show_round()

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
