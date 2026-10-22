class_name MultiplyMultTicket
extends Ticket
## Multiplies the mult.

@export var factor: float = 2.0


func _init() -> void:
	display_name = "×Mult"


func modify_score(_run: RunState, ctx: ScoreContext) -> void:
	ctx.mult *= factor
	ctx.add_trace(self, "×%s mult" % factor)
