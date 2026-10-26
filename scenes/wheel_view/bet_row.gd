class_name BetRow
extends PanelContainer
## One bet in the wheel view: a badge for the bet styled like its table tile, the chips staked on it,
## and × its mult. During the spin the mult counts up live as pass tickets fire. Once the ball lands
## WheelView reveals each row as a hit (the final mult, then "= score" counting up) or a miss (a
## shake, the mult struck out, the row dimmed). Display only. Make one with `of`.

const SCENE := preload("res://scenes/wheel_view/bet_row.tscn")

## Seconds a number takes to count to a new value.
@export var count_duration := 0.3
## The border and flash of a row that hit.
@export var hit_colour := Color("f9d684")
@export var hit_border_width := 4
## How far a missed row fades.
@export_range(0.0, 1.0, 0.05) var miss_alpha := 0.4
## The badge's label size, as a fraction of the table's (which is given at a full-size tile).
@export var badge_font_scale := 0.6
## The "+18" that floats up off the mult when it changes.
@export var float_settings: LabelSettings

var _placed: PlacedBet
var _style: BetTileStyle
var _table_style: TableStyle
var _target_mult := 0.0 # the mult being counted to
var _shown_mult := 0.0 # the mult on screen, which lags the target while it counts
var _mult_tween: Tween

@onready var _badge: PanelContainer = %Badge
@onready var _badge_label: Label = %BadgeLabel
@onready var _stack: ChipStack = %Stack
@onready var _stake: Label = %Stake
@onready var _mult: Label = %Mult
@onready var _strike: ColorRect = %Strike
@onready var _equals: Label = %Equals
@onready var _total: Label = %Total


## A row for `placed`, its badge drawn in `style` (the tile style the table uses for that bet), with
## `table_style` for the default font. Shows the bet's base mult until the spin changes it.
static func of(placed: PlacedBet, style: BetTileStyle, table_style: TableStyle) -> BetRow:
	var row: BetRow = SCENE.instantiate()
	row._placed = placed
	row._style = style
	row._table_style = table_style
	return row


func _ready() -> void:
	_badge_label.text = _placed.bet.display_name.to_upper()
	var settings := LabelSettings.new()
	settings.font = _style.font if _style.font else _table_style.font
	var font_size := _style.font_size if _style.font_size > 0 else _table_style.font_size
	settings.font_size = roundi(font_size * badge_font_scale)
	settings.font_color = _style.font_color
	settings.shadow_size = 0
	settings.shadow_color = _style.shadow_color
	settings.shadow_offset = _style.shadow_offset * badge_font_scale
	_badge_label.label_settings = settings
	_badge.add_theme_stylebox_override("panel",
			_table_style.box(_style.fill, Vector4.ONE * _table_style.corner_radius / 2.0))

	_stack.show_chips(_placed.chips)
	_stack.custom_minimum_size = _stack_size()
	_stake.text = str(_placed.total())
	_target_mult = _placed.bet.base_mult
	_set_shown_mult(_target_mult)


## The bet's live mult during the spin. Counts up to it, pops, and floats the change off the number.
func show_mult(mult: float) -> void:
	if is_equal_approx(mult, _target_mult):
		return
	var change := mult - _target_mult
	_target_mult = mult
	if _mult_tween:
		_mult_tween.kill()
	_mult_tween = create_tween()
	_mult_tween.tween_method(_set_shown_mult, _shown_mult, mult, count_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pop(_mult)
	_float_up(("+" if change > 0.0 else "") + _format(change))


## Reveals the bet as won: counts to its final mult (flat tickets apply on landing), then flashes,
## gets the hit border, and counts "= total" up from 0.
func show_hit(mult: float, total: int) -> void:
	var settle := 0.0
	if not is_equal_approx(mult, _target_mult):
		show_mult(mult)
		settle = count_duration
	var tween := create_tween()
	tween.tween_interval(settle)
	tween.tween_callback(_mark_hit)
	tween.tween_method(func(value: float) -> void: _total.text = str(roundi(value)), 0.0,
			float(total), count_duration * 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_pop.bind(_total))


## Reveals the bet as lost: a quick shake, the mult struck out, and the row fades back.
func show_miss() -> void:
	_strike.show()
	var start := position.x
	var tween := create_tween()
	for offset in [-8.0, 8.0, -5.0, 5.0, 0.0]:
		tween.tween_property(self, "position:x", start + offset, 0.04)
	tween.tween_property(self, "modulate:a", miss_alpha, 0.25)


func _mark_hit() -> void:
	var box: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	box.border_color = hit_colour
	box.set_border_width_all(hit_border_width)
	add_theme_stylebox_override("panel", box)
	_equals.show()
	_total.show()
	_total.text = "0"
	_pop(_badge)
	# Flash bright, then settle.
	modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.3)


func _set_shown_mult(value: float) -> void:
	_shown_mult = value
	_mult.text = _format(value)


# Scales `control` up and springs it back, about its centre.
func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * 1.3
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# A small label that drifts up off the mult and fades out.
func _float_up(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.label_settings = float_settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mult.add_child(label)
	label.position = Vector2(_mult.size.x, -label.get_minimum_size().y / 2.0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 28.0, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


# The chip stack draws from its bottom-left corner, so it needs to be told how big its chips get.
func _stack_size() -> Vector2:
	var counts := {} # tier -> chips of that tier
	for chip in _placed.chips:
		counts[chip.tier] = counts.get(chip.tier, 0) + 1
	var tallest := 0
	for count: int in counts.values():
		tallest = maxi(tallest, mini(count, _stack.max_shown))
	var columns := counts.size()
	return Vector2(columns * _stack.chip_size.x + maxi(columns - 1, 0) * _stack.column_gap,
			_stack.chip_size.y + maxi(tallest - 1, 0) * _stack.chip_rise)


static func _format(mult: float) -> String:
	return String.num(snappedf(mult, 0.01))
