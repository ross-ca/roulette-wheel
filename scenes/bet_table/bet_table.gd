class_name BetTable
extends Container
## The betting table: zero down the left, the numbers in three rows of twelve (3, 6, 9… along the
## top), the dozens below them and red and black along the bottom. Number tiles are square and as
## big as the space allows. The grid lines are a border drawn round each tile, overlapping where
## tiles meet, so empty corners of the layout stay clear. Corners on the outside of the grid are
## rounded, and zero's more than the rest.
## Display only, like BettingView: it reports drops and right-clicks through its signals.

signal chip_dropped(bet: Bet, chip: PlacedChip)
signal cleared(bet: Bet)

const SPOT_SCENE := preload("res://scenes/bet_table/bet_spot.tscn")
const COLUMNS := 12
## Rows of the layout: three rows of numbers, then the dozens, then the colours.
const NUMBER_ROWS := 3
const DOZENS_ROW := 3
const COLOURS_ROW := 4
## Width of zero's column, as a fraction of a number tile.
const ZERO_COLUMN_WIDTH := 0.5

@export var style: TableStyle:
	set(value):
		style = value
		queue_sort()
## Height of the dozens and colours rows, as a fraction of a number tile.
@export_range(0.2, 1.0, 0.05) var outside_row_height := 0.5:
	set(value):
		outside_row_height = value
		queue_sort()

var _spots := {} # Bet.key() -> BetSpot
## Where each spot goes, in grid cells: {spot, column, row, column_span, row_span, zero_corners,
## outside, border}. Column 0 is zero's. `outside` says which of its corners (top-left, top-right,
## bottom-right, bottom-left) are on the outside of the grid, and `border` is the line-coloured box
## _layout makes for _draw to paint behind it.
var _cells: Array[Dictionary] = []
var _pocket_colours := {} # pocket number -> Pocket.colour
var _line := 0.0 # grid line width at the current tile size, for _draw


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_add_spot(NumberBet.of(0), 0, 0, 1, NUMBER_ROWS, true)
	for row in NUMBER_ROWS:
		for column in COLUMNS:
			_add_spot(NumberBet.of(column * 3 + 3 - row), column + 1, row)
	for dozen in 3:
		_add_spot(DozenBet.of(dozen), dozen * 4 + 1, DOZENS_ROW, 4)
	_add_spot(ColourBet.of("red"), 1, COLOURS_ROW, 6)
	_add_spot(ColourBet.of("black"), 7, COLOURS_ROW, 6)
	_find_outside_corners()


## Colours each number's tile by the colour of its pocket in `pockets`.
func show_pockets(pockets: Array[Pocket]) -> void:
	_pocket_colours.clear()
	for pocket in pockets:
		if not _pocket_colours.has(pocket.number):
			_pocket_colours[pocket.number] = pocket.colour
	queue_sort()


## Shows the chips on each spot.
func show_bets(bets: Array[PlacedBet]) -> void:
	for spot: BetSpot in _spots.values():
		spot.show_chips([])
	for placed in bets:
		var spot: BetSpot = _spots.get(placed.bet.key())
		if spot:
			spot.show_chips(placed.chips)


## Locks or unlocks every spot. They're locked while a spin is running.
func set_editable(editable: bool) -> void:
	for spot: BetSpot in _spots.values():
		spot.editable = editable


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout()


func _draw() -> void:
	if style == null:
		return
	for cell in _cells:
		if cell.has("border"):
			var spot: BetSpot = cell.spot
			draw_style_box(cell.border, spot.get_rect().grow(_line))


## Adds a tile for `bet` to the grid. `column` and `row` are the cell its top-left corner sits in;
## `column_span` and `row_span` are how many cells it covers, like colspan and rowspan in a table
## (zero spans three rows, a dozen four columns). `zero_corners` rounds its outside corners by the
## style's `zero_corner_radius` instead of `corner_radius`. Only the cells are recorded here:
## `_layout` turns them into pixels on every resize, once the tile size is known.
func _add_spot(bet: Bet, column: int, row: int, column_span := 1, row_span := 1,
		zero_corners := false) -> void:
	var spot: BetSpot = SPOT_SCENE.instantiate()
	spot.setup(bet)
	spot.chip_dropped.connect(chip_dropped.emit)
	spot.cleared.connect(cleared.emit)
	add_child(spot)
	_spots[bet.key()] = spot
	_cells.append({"spot": spot, "column": column, "row": row,
			"column_span": column_span, "row_span": row_span, "zero_corners": zero_corners})


# A tile's corner is on the outside of the grid when the three cells around it (beside, above or
# below, and diagonally) are all empty. Sets each cell's `outside`. Only runs once per play phase.
func _find_outside_corners() -> void:
	var taken := {} # Vector2i(column, row) -> true
	for cell in _cells:
		for column in cell.column_span:
			for row in cell.row_span:
				taken[Vector2i(cell.column + column, cell.row + row)] = true
	for cell in _cells:
		var left: int = cell.column
		var right: int = cell.column + cell.column_span - 1
		var top: int = cell.row
		var bottom: int = cell.row + cell.row_span - 1
		var corners := [Vector2i(left, top), Vector2i(right, top), Vector2i(right, bottom),
				Vector2i(left, bottom)]
		var outward := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
		var outside: Array[bool] = []
		for i in 4:
			var corner: Vector2i = corners[i]
			var away: Vector2i = outward[i]
			outside.append(not taken.has(corner + Vector2i(away.x, 0))
					and not taken.has(corner + Vector2i(0, away.y))
					and not taken.has(corner + away))
		cell.outside = outside


# Sizes the tiles to the largest square that fits, centres the grid, and places and styles each spot.
func _layout() -> void:
	if style == null:
		return
	# Line width scales with the tile, so solve for the tile with the lines measured in tiles too.
	var line_ratio := style.line_width / style.reference_tile
	var across := COLUMNS + ZERO_COLUMN_WIDTH # zero's column plus the numbers
	var down := NUMBER_ROWS + 2 * outside_row_height
	var tile := minf(size.x / (across + (COLUMNS + 2) * line_ratio),
			size.y / (down + (NUMBER_ROWS + 3) * line_ratio))
	var line := tile * line_ratio
	_line = line
	var grid_size := Vector2(across * tile + (COLUMNS + 2) * line,
			down * tile + (NUMBER_ROWS + 3) * line)
	var origin := ((size - grid_size) / 2.0).floor()

	var column_lefts: Array[float] = []
	var column_widths: Array[float] = []
	var x := origin.x + line
	for column in COLUMNS + 1:
		var width := tile * ZERO_COLUMN_WIDTH if column == 0 else tile
		column_lefts.append(x)
		column_widths.append(width)
		x += width + line

	var row_tops: Array[float] = []
	var row_heights: Array[float] = []
	var y := origin.y + line
	for row in COLOURS_ROW + 1:
		var height := tile if row < NUMBER_ROWS else tile * outside_row_height
		row_tops.append(y)
		row_heights.append(height)
		y += height + line

	var scale_factor := tile / style.reference_tile
	for cell in _cells:
		var spot: BetSpot = cell.spot
		var last_column: int = cell.column + cell.column_span - 1
		var last_row: int = cell.row + cell.row_span - 1
		var rect := Rect2(column_lefts[cell.column], row_tops[cell.row],
				column_lefts[last_column] + column_widths[last_column] - column_lefts[cell.column],
				row_tops[last_row] + row_heights[last_row] - row_tops[cell.row])
		fit_child_in_rect(spot, rect)
		var radius: float = rect.size.x * style.zero_corner_radius if cell.zero_corners \
				else style.corner_radius * scale_factor
		var radii := Vector4.ZERO
		for i in 4:
			if cell.outside[i]:
				radii[i] = radius
		spot.set_style(_style_for(spot.bet), style, scale_factor, radii)
		# The border's curves sit a line width outside the tile's, so the line stays even.
		var border_radii := radii
		for i in 4:
			if radii[i] > 0.0:
				border_radii[i] += line
		cell.border = style.box(style.line_color, border_radii)
	queue_redraw()


# Numbers take their pocket's colour; everything else, colour bets included, the outside style.
func _style_for(bet: Bet) -> BetTileStyle:
	if bet is NumberBet:
		return style.tile(_pocket_colours.get(bet.number, ""))
	return style.outside
