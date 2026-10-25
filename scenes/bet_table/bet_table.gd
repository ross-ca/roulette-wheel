class_name BetTable
extends Container
## The betting table: zero down the left, the numbers in three rows of twelve (3, 6, 9… along the
## top), the dozens below them and red and black along the bottom. Number tiles are square and as
## big as the space allows. The grid lines are a border drawn round each tile, overlapping where
## tiles meet, so empty corners of the layout stay clear.
## Display only, like BettingView: it reports drops and right-clicks through its signals.

signal chip_dropped(bet: Bet, chip: PlacedChip)
signal cleared(bet: Bet)

const SPOT_SCENE := preload("res://scenes/bet_table/bet_spot.tscn")
const COLUMNS := 12
## Rows of the layout: three rows of numbers, then the dozens, then the colours.
const NUMBER_ROWS := 3
const DOZENS_ROW := 3
const COLOURS_ROW := 4

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
## Where each spot goes, in columns and rows: {spot, column, row, columns, rows}. Column 0 is zero's.
var _cells: Array[Dictionary] = []
var _pocket_colours := {} # pocket number -> Pocket.colour
var _line := 0.0 # grid line width at the current tile size, for _draw


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_add_spot(NumberBet.of(0), 0, 0, 1, NUMBER_ROWS)
	for row in NUMBER_ROWS:
		for column in COLUMNS:
			print("adding spot: ", row, ",", column)
			_add_spot(NumberBet.of(column * 3 + 3 - row), column + 1, row)
	for dozen in 3:
		_add_spot(DozenBet.of(dozen), dozen * 4 + 1, DOZENS_ROW, 4)
	_add_spot(ColourBet.of("red"), 1, COLOURS_ROW, 6)
	_add_spot(ColourBet.of("black"), 7, COLOURS_ROW, 6)


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
		var spot: BetSpot = cell.spot
		draw_rect(spot.get_rect().grow(_line), style.line_color)


func _add_spot(bet: Bet, column: int, row: int, columns := 1, rows := 1) -> void:
	var spot: BetSpot = SPOT_SCENE.instantiate()
	spot.setup(bet)
	spot.chip_dropped.connect(chip_dropped.emit)
	spot.cleared.connect(cleared.emit)
	add_child(spot)
	_spots[bet.key()] = spot
	_cells.append({"spot": spot, "column": column, "row": row, "columns": columns, "rows": rows})


# Sizes the tiles to the largest square that fits, centres the grid, and places and styles each spot.
func _layout() -> void:
	if style == null:
		return
	# Line width scales with the tile, so solve for the tile with the lines measured in tiles too.
	var line_ratio := style.line_width / style.reference_tile
	var across := COLUMNS + 1 # zero's column plus the numbers
	var down := NUMBER_ROWS + 2 * outside_row_height
	var tile := minf(size.x / (across + (across + 1) * line_ratio),
			size.y / (down + (NUMBER_ROWS + 3) * line_ratio))
	var line := tile * line_ratio
	_line = line
	var grid_size := Vector2(across * tile + (across + 1) * line,
			down * tile + (NUMBER_ROWS + 3) * line)
	var origin := ((size - grid_size) / 2.0).floor()

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
		var x: float = origin.x + line + cell.column * (tile + line)
		var last_row: int = cell.row + cell.rows - 1
		var rect := Rect2(x, row_tops[cell.row],
				cell.columns * tile + (cell.columns - 1) * line,
				row_tops[last_row] + row_heights[last_row] - row_tops[cell.row])
		fit_child_in_rect(spot, rect)
		spot.set_style(_style_for(spot.bet), style, scale_factor)
	queue_redraw()


# Numbers take their pocket's colour, colour bets their own, and everything else the outside style.
func _style_for(bet: Bet) -> BetTileStyle:
	if bet is NumberBet:
		return style.tile(_pocket_colours.get(bet.number, ""))
	if bet is ColourBet:
		# return style.tile(bet.colour)
		return style.outside
	return style.outside
