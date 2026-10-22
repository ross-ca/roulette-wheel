extends CanvasLayer

signal spin_requested

const WHEEL_COLOURS: Dictionary = preload("res://scenes/wheel/draw_wheel.gd").COLOURS
const POPUP_FONT: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")

## Popups land in the right third of the screen, within the middle 60% vertically.
const POPUP_X_RANGE := Vector2(2.0 / 3.0, 1.0)
const POPUP_Y_RANGE := Vector2(0.2, 0.8)


@onready var _round_label: Label = %RoundLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _spins_label: Label = %SpinsLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _tickets_label: Label = %TicketsLabel
@onready var _last_spin_label: Label = %LastSpinLabel
@onready var _result_label: Label = %ResultLabel
@onready var _chips_input: SpinBox = %ChipsInput
@onready var _red_button: Button = %RedButton
@onready var _black_button: Button = %BlackButton
@onready var _green_button: Button = %GreenButton
@onready var _number_input: LineEdit = %NumberInput

var _inputs_editable := true


func _on_spin_button_pressed() -> void:
	spin_requested.emit()


## The chips entered for the next spin.
func get_chips() -> int:
	_chips_input.apply() # commit text still being typed
	return int(_chips_input.value)


## The bet chosen for the next spin. A number entered in the number field wins out over the colours.
func get_bet() -> Bet:
	if _number_input.text.is_valid_int():
		return NumberBet.of(int(_number_input.text))
	if _black_button.button_pressed:
		return ColourBet.of("black")
	if _green_button.button_pressed:
		return ColourBet.of("green")
	return ColourBet.of("red")


## Locks or unlocks the chips and bet inputs, which are fixed while a spin is running.
func set_inputs_editable(editable: bool) -> void:
	_inputs_editable = editable
	_chips_input.editable = editable
	_number_input.editable = editable
	_refresh_colour_buttons()


# Colours can't be chosen while a number is entered, or while the inputs are locked.
func _refresh_colour_buttons() -> void:
	var disabled := not _inputs_editable or _number_input.text.is_valid_int()
	_red_button.disabled = disabled
	_black_button.disabled = disabled
	_green_button.disabled = disabled


# Keeps the field to a number from 0 to 36.
func _on_number_input_text_changed(new_text: String) -> void:
	var digits := ""
	for character in new_text:
		if character >= "0" and character <= "9":
			digits += character
	if digits.is_valid_int() and int(digits) > 36:
		digits = "36"
	if digits != new_text:
		_number_input.text = digits
		_number_input.caret_column = digits.length()
	_refresh_colour_buttons()


func show_round(run: RunState, step: RoundStep) -> void:
	var progress := run.current_round
	_round_label.text = "Table %d" % run.table
	_score_label.text = "Score %d / %d" % [progress.score, step.target_score]
	_spins_label.text = "Spins left %d" % progress.spins_left
	_money_label.text = "$%d" % run.money
	var names: PackedStringArray = []
	for ticket in run.tickets:
		names.append(ticket.display_name)
	_tickets_label.text = "Tickets: %s" % ", ".join(names)


## Placeholder for the Balatro-style playback: lists what each modifier did, in order.
func show_score(ctx: ScoreContext) -> void:
	var lines: PackedStringArray = ["Landed %d (%s)" % [ctx.pocket.number, ctx.pocket.colour]]
	if not ctx.won:
		lines.append("Bet on %s lost: no points" % ctx.bet.display_name)
		_last_spin_label.text = "\n".join(lines)
		return
	lines.append("%s ×%s base, %d chips" % [ctx.bet.display_name, ctx.bet.base_mult, ctx.points])
	for entry in ctx.trace:
		lines.append(entry.text)
	lines.append("%d × %s = %d" % [ctx.points, ctx.mult, ctx.total()])
	_last_spin_label.text = "\n".join(lines)


func show_result(won: bool) -> void:
	_result_label.text = "Round won!" if won else "Round lost"
	_result_label.show()


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
