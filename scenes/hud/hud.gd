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


func _on_spin_button_pressed() -> void:
	spin_requested.emit()


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
	var lines: PackedStringArray = ["Landed %d: %d points" % [ctx.pocket.number, ctx.points]]
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
