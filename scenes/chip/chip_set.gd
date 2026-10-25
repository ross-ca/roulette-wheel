class_name ChipSet
extends Resource
## The art for each tier of chip. Tiers, not values, pick the art, because chip values are planned
## to follow the player's money while the tiers stay put. Used by Chip and ChipStack.

## One texture per tier, lowest value first: one for each entry in play.gd's CHIP_VALUES.
## ART: chip_set.tres holds placeholder gradients. Replace each with the chip's texture (drag the
## PNG onto the entry in the inspector, or set its path in the .tres).
@export var textures: Array[Texture2D] = []


## The texture for `tier`. Tiers past the end of the list reuse the last texture.
func texture(tier: int) -> Texture2D:
	if textures.is_empty():
		return null
	return textures[clampi(tier, 0, textures.size() - 1)]
