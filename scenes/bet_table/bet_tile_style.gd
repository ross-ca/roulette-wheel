class_name BetTileStyle
extends Resource
## How one kind of tile on the betting table looks: its fill and its label. Sizes are in pixels at
## the table's reference tile size (see TableStyle) and scale with the tile.

@export var fill := Color.BLACK
## Overrides the table style's font for this kind of tile. Leave empty to use the table's.
@export var font: Font
## Overrides the table style's font size, at the reference tile size. 0 uses the table's.
@export var font_size := 0
@export var font_color := Color.WHITE
@export var shadow_color := Color(0, 0, 0, 0)
## A hard drop shadow (no blur), in pixels at the reference tile size.
@export var shadow_offset := Vector2.ZERO
