class_name TableStyle
extends Resource
## How the betting table looks. Number tiles take the style of their pocket's colour, so a run that
## recolours pockets recolours the table to match. Sizes are in pixels at `reference_tile` and scale
## with the actual tile size.

## Keyed by Pocket.colour ("red", "black", "green"). Red and black also style the colour bets.
@export var tiles: Dictionary[String, BetTileStyle] = {}
## Tiles with no pocket colour, such as the dozens.
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


## The style for tiles of pocket colour `colour`.
func tile(colour: String) -> BetTileStyle:
	return tiles.get(colour, fallback)
