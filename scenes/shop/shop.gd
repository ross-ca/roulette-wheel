extends Control
## Stub shop between rounds. Sells nothing yet; it can reverse the ticket order to show that order
## changes the score, and Continue moves the run on.

signal finished(result: Variant)

var _run: RunState

@onready var _money_label: Label = %MoneyLabel
@onready var _tickets_label: Label = %TicketsLabel


## Called by the runner before the scene enters the tree.
func setup(run: RunState, _step: RunStep) -> void:
	_run = run


func _ready() -> void:
	# Running this scene on its own (F6) has no runner.
	if _run == null:
		Game.new_run(randi(), false)
		_run = Game.run
	_refresh()


func _refresh() -> void:
	_money_label.text = "$%d" % _run.money
	var names: PackedStringArray = []
	for ticket in _run.tickets:
		names.append(ticket.display_name)
	_tickets_label.text = "Tickets: %s" % ", ".join(names)


func _on_reverse_button_pressed() -> void:
	_run.tickets.reverse()
	Game.save_run()
	_refresh()


func _on_continue_button_pressed() -> void:
	finished.emit(null)
