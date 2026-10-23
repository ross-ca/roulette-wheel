class_name PassAddMoneyTicket
extends PocketPassTicket
## Pays the player every time the ball passes over a chosen pocket, whether or not the bet wins.

@export var amount: int = 1


func _init() -> void:
	display_name = "+Money per pass"


func get_description() -> String:
	return "+$%s each time the ball passes %s%s" % [amount, _pocket_name(), _chance_text()]


func apply_pass(run: RunState, _ctx: ScoreContext) -> void:
	run.money += amount
	run.current_round.money_earned += amount
