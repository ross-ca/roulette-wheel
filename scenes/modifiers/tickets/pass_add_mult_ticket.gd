class_name PassAddMultTicket
extends PocketPassTicket
## Adds to the mult every time the ball passes over a chosen pocket.

@export var amount: float = 2.0


func _init() -> void:
	display_name = "+Mult per pass"


func get_description() -> String:
	return "+%s mult each time the ball passes %s" % [amount, _pocket_name()]


func modify_score(_run: RunState, ctx: ScoreContext) -> void:
	if _passes == 0:
		return
	ctx.mult += amount * _passes
	ctx.add_trace(self, "+%s mult (%s passes of %s)" % [amount * _passes, _passes, _pocket_name()])
