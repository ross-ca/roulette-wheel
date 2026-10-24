class_name BetSpot
extends Button
## One place on the betting table, backing one bet. Chips dragged from a `Chip` drop here, and
## right-clicking takes them off again. It only reports what happened; play.gd changes the bets.

signal chips_dropped(bet: Bet, chips: int)
signal cleared(bet: Bet)

var bet: Bet
## False while bets can't change, such as during a spin.
var editable := true


static func of(spot_bet: Bet) -> BetSpot:
	var spot := BetSpot.new()
	spot.bet = spot_bet
	spot.focus_mode = Control.FOCUS_NONE
	spot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spot.show_chips(0)
	return spot


## Shows the chips on this spot, 0 for none.
func show_chips(chips: int) -> void:
	text = bet.display_name if chips == 0 else "%s\n%d" % [bet.display_name, chips]


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return editable and data is Dictionary and data.has("chips")


func _drop_data(_at: Vector2, data: Variant) -> void:
	chips_dropped.emit(bet, data.chips)


func _gui_input(event: InputEvent) -> void:
	if editable and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		cleared.emit(bet)
		accept_event()
