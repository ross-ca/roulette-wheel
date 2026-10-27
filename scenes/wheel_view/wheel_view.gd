class_name WheelView
extends Control
## The play phase's wheel screen: the TABLE tab back to betting on the left edge, then the tickets
## and the spin's bets (ticking up live as the ball passes pockets), and the wheel on the right.
## Display only, like BettingView: play.gd decides what its signals do.
##
## The wheel and its SPIN button are drawn in a SubViewport in play.tscn, so the wheel shader bobs
## and shadows the button with the wheel. WheelOutput shows the viewport's texture and forwards the
## mouse into it, since a SubViewport outside a SubViewportContainer gets no input of its own.
## The viewport lays the wheel out at its fixed size_2d_override (the design size) but renders at
## as many pixels as WheelOutput covers on screen, so the wheel stays sharp at any window size.

signal betting_requested
signal spin_requested

## The table's look, so each row's badge matches its bet's tile.
@export var table_style: TableStyle
## Seconds between one row's reveal and the next's once the ball lands.
@export var reveal_gap := 0.18
## Seconds after the last row's reveal before `show_result` returns, so its count-up can finish.
@export var reveal_tail := 0.6
## Played as each winning row is revealed, a little higher for each hit in the spin.
@export var hit_sound: AudioStream
## Played as each losing row is revealed.
@export var miss_sound: AudioStream
@export var reveal_volume_db := -6.0

## Where the shared ticket strip sits while this view is showing. play.gd moves it there.
@onready var ticket_slot: Control = %TicketSlot

@onready var _table_tab: SideTab = %TableTab
@onready var _rows: VBoxContainer = %BetRows
@onready var _breakdown_label: Label = %BreakdownLabel
@onready var _wheel_output: TextureRect = %WheelOutput

var _viewport: SubViewport
var _design_size := Vector2.ZERO # the viewport's size_2d_override, which the wheel is laid out in
var _spin_button: Button
var _pocket_colours := {} # pocket number -> Pocket.colour, for number bets' badges


func _ready() -> void:
	_wheel_output.gui_input.connect(_forward_to_wheel)
	_wheel_output.mouse_entered.connect(_notify_wheel.bind(NOTIFICATION_VP_MOUSE_ENTER))
	_wheel_output.mouse_exited.connect(_notify_wheel.bind(NOTIFICATION_VP_MOUSE_EXIT))
	# The window's stretch scale can change without WheelOutput's size changing, so watch both.
	_wheel_output.resized.connect(_fit_wheel_resolution)
	get_viewport().size_changed.connect(_fit_wheel_resolution)


func _on_back_button_pressed() -> void:
	betting_requested.emit()


## The wheel's SubViewport and the SPIN button in it, which both live in play.tscn. The button is
## sized to cover the wheel's hub, `hub_radius` in the wheel's design pixels, and centred on it.
func set_wheel(viewport: SubViewport, spin_button: Button, hub_radius: float) -> void:
	_viewport = viewport
	_design_size = Vector2(viewport.size_2d_override)
	_wheel_output.texture = viewport.get_texture()
	(_wheel_output.material as ShaderMaterial).set_shader_parameter("design_size", _design_size)
	_spin_button = spin_button
	_spin_button.size = Vector2.ONE * 2.0 * hub_radius
	_spin_button.position = (_design_size - _spin_button.size) / 2.0
	_spin_button.pressed.connect(spin_requested.emit)
	_fit_wheel_resolution()


## Number bets' badges take their pocket's colour, like the table's tiles.
func show_pockets(pockets: Array[Pocket]) -> void:
	_pocket_colours.clear()
	for pocket in pockets:
		if not _pocket_colours.has(pocket.number):
			_pocket_colours[pocket.number] = pocket.colour


## One row per bet, showing its chips × base mult. Clears the last spin's result.
func show_bets(bets: Array[PlacedBet]) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child) # so _row() indexes only count the new rows
		child.queue_free()
	for placed in bets:
		_rows.add_child(BetRow.of(placed, _badge_style(placed.bet), table_style))
	_breakdown_label.text = ""


## The live mults of the spin in progress, which pass tickets change as the ball goes round. Its
## bets are in the same order as the rows.
func show_spin(spin: SpinContext) -> void:
	for i in spin.bets.size():
		_row(i).show_mult(spin.bets[i].mult)


## Reveals the landed spin row by row, top to bottom, each a moment after the last: hits count up to
## their score, misses shake and fade. Returns once the reveal has played, so the caller can wait
## for it. The rows keep showing the result until the bets next change. The breakdown underneath is
## a placeholder list of what each modifier did.
func show_result(spin: SpinContext) -> void:
	var lines: PackedStringArray = ["Landed %d (%s)" % [spin.pocket.number, spin.pocket.colour]]
	for ctx in spin.bets:
		if ctx.won:
			lines.append("%s: %d chips, ×%s base" % [ctx.bet.display_name, ctx.points, ctx.bet.base_mult])
			for entry in ctx.trace:
				lines.append("  %s" % entry.text)
	lines.append("Spin total %d" % spin.total())
	_breakdown_label.text = "\n".join(lines)

	var speed := Settings.animation_speed()
	var hits := 0
	for i in spin.bets.size():
		await get_tree().create_timer(reveal_gap / speed, false).timeout
		var ctx := spin.bets[i]
		if ctx.won:
			_row(i).show_hit(ctx.mult, ctx.total())
			if hit_sound:
				Audio.play_sfx(hit_sound, reveal_volume_db, 1.0 + hits * 0.12)
			hits += 1
		else:
			_row(i).show_miss()
			if miss_sound:
				Audio.play_sfx(miss_sound, reveal_volume_db, randf_range(0.95, 1.05))
	await get_tree().create_timer(reveal_tail / speed, false).timeout


## Locks the way back to betting while the wheel spins, and hides the spin button.
func set_spinning(spinning: bool) -> void:
	_table_tab.disabled = spinning
	_spin_button.visible = not spinning


## A spin needs at least one bet.
func set_can_spin(can_spin: bool) -> void:
	_spin_button.disabled = not can_spin


func _row(index: int) -> BetRow:
	return _rows.get_child(index)


# The tile style the table uses for `bet`, except that colour bets take their colour's rather than
# the outside style, so RED reads red.
func _badge_style(bet: Bet) -> BetTileStyle:
	if bet is NumberBet:
		return table_style.tile(_pocket_colours.get(bet.number, ""))
	if bet is ColourBet:
		return table_style.tile(bet.colour)
	return table_style.outside


# How much bigger than its design size the wheel is drawn in WheelOutput, which shows the texture as
# big as fits and centred (keep aspect centred).
func _shown_scale() -> float:
	return minf(_wheel_output.size.x / _design_size.x, _wheel_output.size.y / _design_size.y)


# Renders the wheel at the pixels it covers on screen: its shown size times the window's stretch
# scale (1920x1080 is scaled to fit the window).
func _fit_wheel_resolution() -> void:
	if _viewport == null:
		return
	var screen_scale := get_viewport().get_final_transform().get_scale() \
			* _wheel_output.get_global_transform_with_canvas().get_scale()
	var pixels := (_design_size * _shown_scale() * screen_scale).ceil()
	if pixels.x >= 1.0 and pixels.y >= 1.0:
		_viewport.size = Vector2i(pixels)


# Passes mouse events on WheelOutput into the viewport, moved from WheelOutput's space into the
# wheel's design space (local coordinates skip the viewport's stretch, so they go in unscaled). The
# shader's bob isn't accounted for, so the clickable hub sits where the wheel is at rest.
func _forward_to_wheel(event: InputEvent) -> void:
	if _viewport == null or not (event is InputEventMouse):
		return
	var shown := _shown_scale()
	var offset := (_wheel_output.size - _design_size * shown) / 2.0
	var local: InputEventMouse = event.duplicate()
	local.position = (event.position - offset) / shown
	local.global_position = local.position
	_viewport.push_input(local, true)


func _notify_wheel(what: int) -> void:
	if _viewport:
		_viewport.notification(what)
