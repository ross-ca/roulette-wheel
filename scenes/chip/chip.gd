class_name Chip
extends Control
## A chip in the betting view's row. Dragging it onto a `BetSpot` stakes a chip of its value there.
## Instance chip.tscn and call `setup`; the art comes from `chip_set`.

@export var chip_set: ChipSet

var value := 0
var tier := 0
## A disabled chip can't be dragged. Set while bets are locked, such as during a spin.
var disabled := false:
	set(new_disabled):
		disabled = new_disabled
		modulate.a = 0.5 if disabled else 1.0

@onready var _texture: TextureRect = $Texture
@onready var _value_label: Label = $Value


## Shows a chip of `chip_value`, drawn as `chip_tier`. Can be called before the chip enters the tree.
func setup(chip_value: int, chip_tier: int) -> void:
	value = chip_value
	tier = chip_tier
	if is_node_ready():
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	_texture.texture = chip_set.texture(tier)
	_value_label.text = str(value)


func _get_drag_data(_at: Vector2) -> Variant:
	if disabled:
		return null
	# The preview is another chip, held by its centre.
	var chip: Chip = load(scene_file_path).instantiate()
	chip.setup(value, tier)
	chip.size = size
	chip.position = -size / 2.0
	var preview := Control.new()
	preview.add_child(chip)
	set_drag_preview(preview)
	return {"chip": PlacedChip.of(value, tier)}
