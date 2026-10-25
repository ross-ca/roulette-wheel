class_name TableStyle
extends Resource
## How the betting table looks. Number tiles take the style of their pocket's colour, so a run that
## recolours pockets recolours the table to match. Sizes are in pixels at `reference_tile` and scale
## with the actual tile size.

## Keyed by Pocket.colour ("red", "black", "green").
@export var tiles: Dictionary[String, BetTileStyle] = {}
## Every tile that isn't a number: the dozens and the even-money bets along the bottom.
@export var outside: BetTileStyle
## Used for a pocket colour missing from `tiles`.
@export var fallback: BetTileStyle

@export var font: Font
## Label size in pixels at the reference tile size.
@export var font_size := 24
## The tile size the other sizes are given at: a tile on a 1920×1080 screen.
@export var reference_tile := 141.5
@export var line_color := Color.WHITE
## Width of the grid lines, in pixels at the reference tile size.
@export var line_width := 2.0
## Rounding of the grid's outside corners, in pixels at the reference tile size. Corners where tiles
## meet stay square.
@export var corner_radius := 12.0
## Rounding of zero's outside corners, as a fraction of its width: 0.5 rounds them into quarter
## circles half the tile wide, 1 makes zero's top and bottom one quarter circle each.
@export_range(0.0, 1.0, 0.05) var zero_corner_radius := 0.5
## Off gives hard, stepped curves that suit pixel art.
@export var smooth_corners := true


## The style for tiles of pocket colour `colour`.
func tile(colour: String) -> BetTileStyle:
	return tiles.get(colour, fallback)


## A box filled with `colour` whose corners are rounded by `radii` (top-left, top-right,
## bottom-right, bottom-left), in actual pixels.
func box(colour: Color, radii: Vector4) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = colour
	result.corner_radius_top_left = roundi(radii.x)
	result.corner_radius_top_right = roundi(radii.y)
	result.corner_radius_bottom_right = roundi(radii.z)
	result.corner_radius_bottom_left = roundi(radii.w)
	result.corner_detail = 16
	result.anti_aliasing = smooth_corners
	return result
