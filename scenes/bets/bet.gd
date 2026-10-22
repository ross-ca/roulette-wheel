class_name Bet
extends Resource
## Something the player can place a bet on. If the landed pocket satisfies `wins()` the spin scores
## `chips × (base_mult + modifiers)`, otherwise it scores nothing.
##
## `base_mult` follows the odds: 36 divided by the numbers the bet covers, so red or black
## (18 numbers) is ×2 and a single number, zero included, is ×36. Subclasses set it themselves.

@export var display_name: String = ""
@export var base_mult: float = 1.0


func wins(_pocket: Pocket) -> bool:
	return false
