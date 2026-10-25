class_name BetRow
extends Label
## One bet in the wheel view: its name and chips × mult, ticking up live as the ball passes pockets.

var _bet_name := ""
var _shown_mult := -1.0
var _pulse: Tween


## A row showing `placed` before the spin: its chips × its base mult.
static func of(placed: PlacedBet) -> BetRow:
	var row := BetRow.new()
	row._bet_name = placed.bet.display_name
	row._shown_mult = placed.bet.base_mult
	row._set_equation(placed.total(), placed.bet.base_mult)
	return row


## The bet's live equation. Pulses when the mult has changed since it was last shown, so each pass
## ticket visibly bumps it. Pass `total` (-1 for none) to append "= total" once settled.
func show_equation(points: int, mult: float, total := -1) -> void:
	_set_equation(points, mult, total)
	if is_equal_approx(mult, _shown_mult):
		return
	_shown_mult = mult
	pivot_offset = Vector2(0.0, size.y / 2.0) # text is left-aligned, so grow from the left
	if _pulse:
		_pulse.kill()
	scale = Vector2(1.3, 1.3)
	_pulse = create_tween()
	_pulse.tween_property(self, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_lost() -> void:
	text = "%s: lost" % _bet_name


func _set_equation(points: int, mult: float, total := -1) -> void:
	text = "%s: %d × %s" % [_bet_name, points, String.num(snappedf(mult, 0.01))]
	if total >= 0:
		text += " = %d" % total
