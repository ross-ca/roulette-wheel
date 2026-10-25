class_name BetSpot
extends Control
## One tile on the betting table, backing one bet: a filled tile with the bet's name centred on it.
## Chips dragged from a `Chip` drop here and are drawn on it by a ChipStack; right-clicking takes
## them all off again. It only reports what happened; play.gd changes the bets.
## Instance bet_spot.tscn and call `setup`; BetTable lays it out and styles it.

signal chip_dropped(bet: Bet, chip: PlacedChip)
signal cleared(bet: Bet)

var bet: Bet
## False while bets can't change, such as during a spin.
var editable := true

var _style: BetTileStyle
var _table_style: TableStyle
var _scale := 1.0 # the tile's size relative to the table style's reference tile
var _box: StyleBoxFlat

@onready var _label: Label = $Label
@onready var _stack: ChipStack = $ChipStack


## Call before the spot enters the tree.
func setup(spot_bet: Bet) -> void:
	bet = spot_bet


func _ready() -> void:
	_label.text = bet.display_name
	_label.label_settings = LabelSettings.new()
	_refresh()


## Draws the tile with `style`, using `table_style` for the font. `scale_factor` is the tile's size
## relative to the table style's reference tile, so text and shadows scale with it. `corner_radii`
## rounds the tile's corners (top-left, top-right, bottom-right, bottom-left), in actual pixels.
func set_style(style: BetTileStyle, table_style: TableStyle, scale_factor: float,
		corner_radii := Vector4.ZERO) -> void:
	_style = style
	_table_style = table_style
	_scale = scale_factor
	_box = table_style.box(style.fill, corner_radii)
	_refresh()


## Shows the chips on this spot, in the order they were dropped.
func show_chips(chips: Array[PlacedChip]) -> void:
	_stack.show_chips(chips)


func _refresh() -> void:
	if not is_node_ready() or _style == null:
		return
	var settings := _label.label_settings
	# The tile's own font and size win; otherwise the table's.
	settings.font = _style.font if _style.font else _table_style.font
	var font_size := _style.font_size if _style.font_size > 0 else _table_style.font_size
	settings.font_size = maxi(roundi(font_size * _scale), 1)
	settings.font_color = _style.font_color
	settings.shadow_color = _style.shadow_color
	settings.shadow_offset = _style.shadow_offset * _scale
	settings.shadow_size = 0
	queue_redraw()


func _draw() -> void:
	if _box:
		draw_style_box(_box, Rect2(Vector2.ZERO, size))


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return editable and data is Dictionary and data.has("chip")


func _drop_data(_at: Vector2, data: Variant) -> void:
	chip_dropped.emit(bet, data.chip)


func _gui_input(event: InputEvent) -> void:
	if editable and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.pressed:
		cleared.emit(bet)
		accept_event()
