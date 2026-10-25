class_name WheelView
extends Control
## The play phase's wheel screen: the TABLE tab back to betting on the left edge, then the tickets
## and the spin's bets (ticking up live as the ball passes pockets), and the wheel on the right. Display only, like
## BettingView: play.gd decides what its signals do.

signal betting_requested
signal spin_requested

## Where the shared ticket strip sits while this view is showing. play.gd moves it there.
@onready var ticket_slot: Control = %TicketSlot

@onready var _table_tab: SideTab = %TableTab
@onready var _spin_button: Button = %SpinButton
@onready var _rows: VBoxContainer = %BetRows
@onready var _breakdown_label: Label = %BreakdownLabel
@onready var _wheel_output: TextureRect = %WheelOutput


func _on_back_button_pressed() -> void:
	betting_requested.emit()


func _on_spin_button_pressed() -> void:
	spin_requested.emit()


## The wheel's SubViewport texture, which lives in play.tscn.
func set_wheel_texture(texture: Texture2D) -> void:
	_wheel_output.texture = texture


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
	_spin_button.text = "Click to spin" if can_spin else "Place a bet first"


func _row(index: int) -> BetRow:
	return _rows.get_child(index)
