class_name BettingView
extends Control
## The play phase's betting screen: money, score and rolls along the top, the table, the tickets,
## consumables and the chips to drag onto the table along the bottom (left, middle and right), and
## the WHEEL tab on the right edge.
## Display only: it reports what the player does through its signals, and play.gd decides what
## happens.

signal bet_placed(bet: Bet, chip: PlacedChip)
signal bet_cleared(bet: Bet)
signal wheel_requested
## A table tile was left-clicked (not a chip drop), e.g. to target a consumable.
signal spot_clicked(bet: Bet)
signal consumable_clicked(item: Consumable)
signal consumables_reordered

const CHIP_SCENE := preload("res://scenes/chip/chip.tscn")
## Most chips in a row before they wrap onto another. The rows are kept even, so seven chips make
## a row of four and a row of three.
const CHIPS_PER_ROW := 5

## Where the shared ticket strip sits while this view is showing. play.gd moves it there.
@onready var ticket_slot: Control = %TicketSlot

@onready var _money: StatDisplay = %MoneyDisplay
@onready var _rolls: StatDisplay = %RollsDisplay
@onready var _score: StatDisplay = %ScoreDisplay
@onready var _table: BetTable = %Table
@onready var _chips: VBoxContainer = %Chips # one centred HBoxContainer per row of chips
@onready var _consumables: CardContainer = %Consumables


func _ready() -> void:
	_table.chip_dropped.connect(bet_placed.emit)
	_table.cleared.connect(bet_cleared.emit)
	_table.spot_clicked.connect(spot_clicked.emit)
	_consumables.item_clicked.connect(func(item: Modifier) -> void: consumable_clicked.emit(item))
	_consumables.order_changed.connect(consumables_reordered.emit)


## Shows the consumables the player holds, as cards.
func show_consumables(items: Array[Consumable]) -> void:
	_consumables.set_items(items)


## The consumables in their on-screen order, after the player has dragged them about.
func get_consumables() -> Array[Modifier]:
	return _consumables.get_items()


## Raises the card of the consumable waiting for its target. Null puts them all down.
func select_consumable(item: Consumable) -> void:
	_consumables.select_item(item)


## Dissolves the card of a consumable that's been used. Await it.
func remove_consumable(item: Consumable) -> void:
	await _consumables.remove_item(item)


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


## Replaces the chips with one per value, in order, in centred rows. A chip's tier is its index here.
func set_chip_values(values: Array[int]) -> void:
	for row in _chips.get_children():
		_chips.remove_child(row) # so set_editable only sees the new rows
		row.queue_free()
	var rows := ceili(values.size() / float(CHIPS_PER_ROW))
	var per_row := ceili(values.size() / float(maxi(rows, 1)))
	var row: HBoxContainer
	for tier in values.size():
		if tier % per_row == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_chips.add_child(row)
		var chip: Chip = CHIP_SCENE.instantiate()
		chip.setup(values[tier], tier)
		row.add_child(chip)


## Shows the chips on each spot of the table.
func show_bets(bets: Array[PlacedBet]) -> void:
	_table.show_bets(bets)


## Locks or unlocks the table and chips. They're locked while a spin is running.
func set_editable(editable: bool) -> void:
	_table.set_editable(editable)
	for row in _chips.get_children():
		for chip: Chip in row.get_children():
			chip.disabled = not editable
