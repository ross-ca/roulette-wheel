class_name BettingView
extends Control
## The play phase's betting screen: round info along the top, the table, the chips to drag onto it,
## and the tickets, consumables and the way to the wheel along the bottom. Display only: it reports
## what the player does through its signals, and play.gd decides what happens.

signal bet_placed(bet: Bet, chips: int)
signal bet_cleared(bet: Bet)
signal wheel_requested

## Numbers across the table; each column holds three, counting up from the bottom row.
const TABLE_COLUMNS := 12

## Where the shared ticket strip sits while this view is showing. play.gd moves it there.
@onready var ticket_slot: Control = %TicketSlot

@onready var _money_label: Label = %MoneyLabel
@onready var _spins_label: Label = %SpinsLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _table: HBoxContainer = %Table
@onready var _chips: HBoxContainer = %Chips

var _spots := {} # Bet.key() -> BetSpot


func _ready() -> void:
	_build_table()


func _on_wheel_button_pressed() -> void:
	wheel_requested.emit()


func show_round(run: RunState, step: RoundStep) -> void:
	var progress := run.current_round
	_money_label.text = "$%d" % run.money
	_spins_label.text = "Rolls left %d" % progress.spins_left
	_score_label.text = "Score %d / %d" % [progress.score, step.target_score]


## Replaces the chips in the row with one per value, in order.
func set_chip_values(values: Array[int]) -> void:
	for child in _chips.get_children():
		child.queue_free()
	for value in values:
		_chips.add_child(Chip.of(value))


## Shows the chips on each spot of the table.
func show_bets(bets: Array[PlacedBet]) -> void:
	for spot: BetSpot in _spots.values():
		spot.show_chips(0)
	for placed in bets:
		var spot: BetSpot = _spots.get(placed.bet.key())
		if spot:
			spot.show_chips(placed.chips)


## Locks or unlocks the table and chips. They're locked while a spin is running.
func set_editable(editable: bool) -> void:
	for spot: BetSpot in _spots.values():
		spot.editable = editable
	for chip: Chip in _chips.get_children():
		chip.disabled = not editable


# Zero on the left, then the numbers in three rows (3, 6, 9… along the top) with the colours below.
func _build_table() -> void:
	_add_spot(NumberBet.of(0), _table)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table.add_child(right)

	var numbers := GridContainer.new()
	numbers.columns = TABLE_COLUMNS
	numbers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(numbers)
	for row in 3:
		for column in TABLE_COLUMNS:
			_add_spot(NumberBet.of(column * 3 + 3 - row), numbers)

	var colours := HBoxContainer.new()
	right.add_child(colours)
	for colour in ["red", "black"]:
		_add_spot(ColourBet.of(colour), colours)


func _add_spot(bet: Bet, parent: Control) -> void:
	var spot := BetSpot.of(bet)
	spot.chips_dropped.connect(bet_placed.emit)
	spot.cleared.connect(bet_cleared.emit)
	parent.add_child(spot)
	_spots[bet.key()] = spot
