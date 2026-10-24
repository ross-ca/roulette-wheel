class_name Chip
extends Button
## A chip in the betting view's row. Dragging it onto a `BetSpot` stakes its value there.

var value := 0


static func of(chip_value: int) -> Chip:
	var chip := Chip.new()
	chip.value = chip_value
	chip.text = str(chip_value)
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(80, 0)
	return chip


func _get_drag_data(_at: Vector2) -> Variant:
	if disabled:
		return null
	var preview := Label.new()
	preview.text = str(value)
	set_drag_preview(preview)
	return {"chips": value}
