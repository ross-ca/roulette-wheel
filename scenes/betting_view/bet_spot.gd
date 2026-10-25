class_name BetSpot
extends Button
## One place on the betting table, backing one bet. Chips dragged from a `Chip` drop here and are
## drawn on it by a ChipStack; right-clicking takes them all off again. It only reports what
## happened; play.gd changes the bets.

signal chip_dropped(bet: Bet, chip: PlacedChip)
signal cleared(bet: Bet)

const CHIP_STACK_SCENE := preload("res://scenes/chip/chip_stack.tscn")

var bet: Bet
## False while bets can't change, such as during a spin.
var editable := true

var _stack: ChipStack


static func of(spot_bet: Bet) -> BetSpot:
	var spot := BetSpot.new()
	spot.bet = spot_bet
	spot.focus_mode = Control.FOCUS_NONE
	spot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spot._stack = CHIP_STACK_SCENE.instantiate()
	spot.add_child(spot._stack)
	spot.show_chips([])
	return spot


## Shows the chips on this spot, in the order they were dropped.
func show_chips(chips: Array[PlacedChip]) -> void:
	var total := 0
	for chip in chips:
		total += chip.value
	text = bet.display_name if total == 0 else "%s\n%d" % [bet.display_name, total]
	_stack.show_chips(chips)


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return editable and data is Dictionary and data.has("chip")


func _drop_data(_at: Vector2, data: Variant) -> void:
	chip_dropped.emit(bet, data.chip)


func _gui_input(event: InputEvent) -> void:
	if editable and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		cleared.emit(bet)
		accept_event()
