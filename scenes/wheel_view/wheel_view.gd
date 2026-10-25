class_name WheelView
extends Control
## The play phase's wheel screen: the TABLE tab back to betting on the left edge, then the tickets
## and the spin's bets (ticking up live as the ball passes pockets), and the wheel on the right.
## Display only, like BettingView: play.gd decides what its signals do.
##
## The wheel and its SPIN button are drawn in a SubViewport in play.tscn, so the wheel shader bobs
## and shadows the button with the wheel. WheelOutput shows the viewport's texture and forwards the
## mouse into it, since a SubViewport outside a SubViewportContainer gets no input of its own.

signal betting_requested
signal spin_requested

## Where the shared ticket strip sits while this view is showing. play.gd moves it there.
@onready var ticket_slot: Control = %TicketSlot

@onready var _table_tab: SideTab = %TableTab
@onready var _rows: VBoxContainer = %BetRows
@onready var _breakdown_label: Label = %BreakdownLabel
@onready var _wheel_output: TextureRect = %WheelOutput

var _viewport: SubViewport
var _spin_button: Button


func _ready() -> void:
	_wheel_output.gui_input.connect(_forward_to_wheel)
	_wheel_output.mouse_entered.connect(_notify_wheel.bind(NOTIFICATION_VP_MOUSE_ENTER))
	_wheel_output.mouse_exited.connect(_notify_wheel.bind(NOTIFICATION_VP_MOUSE_EXIT))


func _on_back_button_pressed() -> void:
	betting_requested.emit()


## The wheel's SubViewport and the SPIN button in it, which both live in play.tscn. The button is
## sized to cover the wheel's hub, `hub_radius` in the viewport's pixels, and centred on it.
func set_wheel(viewport: SubViewport, spin_button: Button, hub_radius: float) -> void:
	_viewport = viewport
	_wheel_output.texture = viewport.get_texture()
	_spin_button = spin_button
	_spin_button.size = Vector2.ONE * 2.0 * hub_radius
	_spin_button.position = (Vector2(viewport.size) - _spin_button.size) / 2.0
	_spin_button.pressed.connect(spin_requested.emit)


## One row per bet, showing its chips × base mult. Clears the last spin's result.
func show_bets(bets: Array[PlacedBet]) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child) # so _row() indexes only count the new rows
		child.queue_free()
	for placed in bets:
		_rows.add_child(BetRow.of(placed))
	_breakdown_label.text = ""


## The live equations of the spin in progress. Its bets are in the same order as the rows.
func show_spin(spin: SpinContext) -> void:
	for i in spin.bets.size():
		_row(i).show_equation(spin.bets[i].points, spin.bets[i].mult)


## Placeholder for the Balatro-style playback: each bet's final score, and a list of what each
## modifier did to it, in order. Stays until the bets next change.
func show_result(spin: SpinContext) -> void:
	var lines: PackedStringArray = ["Landed %d (%s)" % [spin.pocket.number, spin.pocket.colour]]
	for i in spin.bets.size():
		var ctx := spin.bets[i]
		if not ctx.won:
			_row(i).show_lost()
			continue
		_row(i).show_equation(ctx.points, ctx.mult, ctx.total())
		lines.append("%s: %d chips, ×%s base" % [ctx.bet.display_name, ctx.points, ctx.bet.base_mult])
		for entry in ctx.trace:
			lines.append("  %s" % entry.text)
	lines.append("Spin total %d" % spin.total())
	_breakdown_label.text = "\n".join(lines)


## Locks the way back to betting while the wheel spins, and hides the spin button.
func set_spinning(spinning: bool) -> void:
	_table_tab.disabled = spinning
	_spin_button.visible = not spinning


## A spin needs at least one bet.
func set_can_spin(can_spin: bool) -> void:
	_spin_button.disabled = not can_spin


func _row(index: int) -> BetRow:
	return _rows.get_child(index)


# Passes mouse events on WheelOutput into the viewport, moved from WheelOutput's space into the
# viewport's. The texture is drawn as big as fits and centred (keep aspect centred). The shader's bob
# isn't accounted for, so the clickable hub sits where the wheel is at rest.
func _forward_to_wheel(event: InputEvent) -> void:
	if _viewport == null or not (event is InputEventMouse):
		return
	var texture_size := Vector2(_viewport.size)
	var shown := minf(_wheel_output.size.x / texture_size.x, _wheel_output.size.y / texture_size.y)
	var offset := (_wheel_output.size - texture_size * shown) / 2.0
	var local: InputEventMouse = event.duplicate()
	local.position = (event.position - offset) / shown
	local.global_position = local.position
	_viewport.push_input(local, true)


func _notify_wheel(what: int) -> void:
	if _viewport:
		_viewport.notification(what)
