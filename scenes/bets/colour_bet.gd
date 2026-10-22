class_name ColourBet
extends Bet
## Bet on the colour of the landed pocket. Red and black cover 18 numbers (×2); green is only zero (×36).

@export_enum("red", "black", "green") var colour: String = "red":
	set(value):
		colour = value
		base_mult = 36.0 if colour == "green" else 2.0


## A bet on `bet_colour`.
static func of(bet_colour: String) -> ColourBet:
	var bet := ColourBet.new()
	bet.colour = bet_colour
	bet.display_name = bet_colour.capitalize()
	return bet


func _init() -> void:
	base_mult = 2.0 # matches the default colour


func wins(pocket: Pocket) -> bool:
	return pocket.colour == colour
