extends Control
## Stub shop between rounds. It shows the step's stock, rolled by rarity, but can't sell it yet, and
## the stock can be rerolled for a price. It can reverse the ticket order to show that order changes
## the score, and Continue moves the run on.

signal finished(result: Variant)

var _run: RunState
var _step: ShopStep

@onready var _stock: CardContainer = %Stock
@onready var _money_label: Label = %MoneyLabel
@onready var _tickets_label: Label = %TicketsLabel
@onready var _reroll_button: Button = %RerollButton


## Called by the runner before the scene enters the tree.
func setup(run: RunState, step: RunStep) -> void:
	_run = run
	_step = step


func _ready() -> void:
	# Running this scene on its own (F6) has no runner.
	if _run == null:
		Game.new_run(randi(), false)
		_run = Game.run
		_step = ShopStep.new()
		_run.current_step = _step

	if not _step.stocked:
		_step.stock_up(_run, Game.TICKET_DATABASE)
		Game.save_run()
	_stock.set_items(_step.stock)
	_refresh()


func _refresh() -> void:
	_money_label.text = "$%d" % _run.money
	var reroll_cost := _reroll_cost()
	_reroll_button.text = "Reroll ($%d)" % reroll_cost
	_reroll_button.disabled = _run.money < reroll_cost
	var names: PackedStringArray = []
	for ticket in _run.tickets:
		names.append(ticket.display_name)
	_tickets_label.text = "Tickets: %s" % ", ".join(names)


func _reroll_cost() -> int:
	return Modifiers.price(_run, ShopStep.REROLL_COST)


func _on_reroll_button_pressed() -> void:
	var cost := _reroll_cost()
	if _run.money < cost:
		return
	_run.money -= cost
	_step.reroll(_run, Game.TICKET_DATABASE)
	_stock.set_items(_step.stock)
	Game.save_run()
	_refresh()


func _on_reverse_button_pressed() -> void:
	_run.tickets.reverse()
	Game.save_run()
	_refresh()


func _on_continue_button_pressed() -> void:
	finished.emit(null)
