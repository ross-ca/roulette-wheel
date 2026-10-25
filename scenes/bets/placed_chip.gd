class_name PlacedChip
extends Resource
## One chip on a bet. Bets keep their chips one by one, rather than as a total, so the table shows
## the chips actually dropped, and so chips can gain properties of their own later.

@export var value: int = 0
## Which kind of chip it is, from 0 for the lowest value. Picks its art from the ChipSet. Kept
## apart from `value` because chip values are planned to follow the player's money.
@export var tier: int = 0


static func of(chip_value: int, chip_tier: int) -> PlacedChip:
	var chip := PlacedChip.new()
	chip.value = chip_value
	chip.tier = chip_tier
	return chip
