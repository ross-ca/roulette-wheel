class_name AddMultTicket
extends Ticket
## Adds a flat amount to the mult.

@export var amount: float = 4.0


func _init() -> void:
	display_name = "+Mult"


func get_description() -> String:
	return "+%s mult" % amount


func modify_score(_run: RunState, ctx: ScoreContext) -> void:
	ctx.mult += amount
	ctx.add_trace(self, "+%s mult" % amount)
