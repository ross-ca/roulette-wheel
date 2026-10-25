class_name BettingView
extends Control
## The play phase's betting screen: money, score and rolls along the top, the table, the chips to drag onto it,
## and the tickets, consumables and the way to the wheel along the bottom. Display only: it reports
## what the player does through its signals, and play.gd decides what happens.

signal bet_placed(bet: Bet, chip: PlacedChip)
signal bet_cleared(bet: Bet)
signal wheel_requested

const CHIP_SCENE := preload("res://scenes/chip/chip.tscn")

## Where the shared ticket strip sits while this view is showing. play.gd moves it there.
@onready var ticket_slot: Control = %TicketSlot

@onready var _money: StatDisplay = %MoneyDisplay
@onready var _rolls: StatDisplay = %RollsDisplay
@onready var _score: StatDisplay = %ScoreDisplay
@onready var _table: BetTable = %Table
@onready var _chips: HBoxContainer = %Chips


func _ready() -> void:
	_table.chip_dropped.connect(bet_placed.emit)
	_table.cleared.connect(bet_cleared.emit)


func _on_wheel_button_pressed() -> void:
	wheel_requested.emit()


func show_round(run: RunState, _step: RoundStep) -> void:
	var progress := run.current_round
	_money.value = run.money
	_rolls.value = progress.spins_left
	_score.value = progress.score


## Colours the table's number tiles by their pockets' colours.
func show_pockets(pockets: Array[Pocket]) -> void:
	_table.show_pockets(pockets)


## Replaces the chips in the row with one per value, in order. A chip's tier is its index here.
func set_chip_values(values: Array[int]) -> void:
	for child in _chips.get_children():
		child.queue_free()
	for tier in values.size():
		var chip: Chip = CHIP_SCENE.instantiate()
		chip.setup(values[tier], tier)
		_chips.add_child(chip)


## Shows the chips on each spot of the table.
func show_bets(bets: Array[PlacedBet]) -> void:
	_table.show_bets(bets)


## Locks or unlocks the table and chips. They're locked while a spin is running.
func set_editable(editable: bool) -> void:
	_table.set_editable(editable)
	for chip: Chip in _chips.get_children():
		chip.disabled = not editable
