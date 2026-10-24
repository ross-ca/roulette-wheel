extends CanvasLayer
## Overlay above both play views: the round's result with its Continue button, and the pass popups.
## The round info, bets and score live in BettingView and WheelView.

signal continue_requested

const WHEEL_COLOURS: Dictionary = preload("res://scenes/wheel/draw_wheel.gd").COLOURS
const POPUP_FONT: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")

## Popups land in the right third of the screen, within the middle 60% vertically.
const POPUP_X_RANGE := Vector2(2.0 / 3.0, 1.0)
const POPUP_Y_RANGE := Vector2(0.2, 0.8)


@onready var _result_label: Label = %ResultLabel
@onready var _continue_button: Button = %ContinueButton


func _on_continue_button_pressed() -> void:
	_continue_button.hide()
	continue_requested.emit()


## Shows the round's result and a Continue button; the run only moves on when it's pressed.
func show_result(won: bool) -> void:
	_result_label.text = "Round won!" if won else "Round lost"
	_result_label.show()
	_continue_button.show()
	_continue_button.grab_focus()


## Throwaway visualisation: pops the number of a passed pocket, then lets it rise and fade.
func show_pass(pocket: Pocket) -> void:
	var settings := LabelSettings.new()
	settings.font = POPUP_FONT
	settings.font_size = 40
	settings.font_color = WHEEL_COLOURS[pocket.colour]
	settings.outline_size = 8
	settings.outline_color = WHEEL_COLOURS["gold"]

	var label := Label.new()
	label.label_settings = settings
	label.text = str(pocket.number)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(label)

	label.reset_size()
	label.pivot_offset = label.size / 2.0
	# Pick the label's centre in the popup region, keeping the whole label on screen.
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2 = label.size / 2.0
	var centre := Vector2(
		randf_range(screen.x * POPUP_X_RANGE.x + half.x, screen.x * POPUP_X_RANGE.y - half.x),
		randf_range(screen.y * POPUP_Y_RANGE.x + half.y, screen.y * POPUP_Y_RANGE.y - half.y)
	)
	var start: Vector2 = centre - half
	label.position = start
	label.scale = Vector2(0.4, 0.4)

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", start.y - 70.0, 0.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
