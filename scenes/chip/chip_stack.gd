class_name ChipStack
extends Control
## Draws the chips on one bet, grouped by tier: a column per tier, highest on the left, each chip a
## little above the one under it. Past `max_shown` chips a column stops growing and shows a count.
## Display only, and ignores the mouse, so drops and clicks reach whatever it's drawn over.

@export var chip_set: ChipSet
## Size of each chip drawn in the stack.
@export var chip_size := Vector2(56, 56)
## How far each chip sits above the one under it.
@export var chip_rise := 4.0
## Chips drawn in a column before it shows a count instead of growing.
@export var max_shown := 5
## Gap between neighbouring columns.
@export var column_gap := 2.0

var _chips: Array[PlacedChip] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)


func show_chips(chips: Array[PlacedChip]) -> void:
	_chips = chips.duplicate()
	_layout()


# Rebuilt from scratch: stacks are small, and it only happens when the bet or the size changes.
func _layout() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var counts := {} # tier -> chips of that tier
	for chip in _chips:
		counts[chip.tier] = counts.get(chip.tier, 0) + 1
	var tiers := counts.keys()
	tiers.sort()
	tiers.reverse()

	# Columns are left-aligned along the bottom edge.
	var x := 0
	for tier in tiers:
		var count: int = counts[tier]
		var shown := mini(count, max_shown)
		for i in shown:
			var rect := TextureRect.new()
			rect.texture = chip_set.texture(tier)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.size = chip_size
			rect.position = Vector2(x, size.y - chip_size.y - i * chip_rise)
			add_child(rect)
		if count > shown:
			var label := Label.new()
			label.text = "×%d" % count
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 12)
			add_child(label)
			label.reset_size()
			label.position = Vector2(x + (chip_size.x - label.size.x) / 2.0,
					size.y - chip_size.y - shown * chip_rise - label.size.y)
		x += chip_size.x + column_gap
