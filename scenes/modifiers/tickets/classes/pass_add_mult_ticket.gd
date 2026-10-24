class_name PassAddMultTicket
extends PocketPassTicket
## Adds to every bet's mult every time the ball passes over a chosen pocket.

@export var amount: float = 2.0


func _init() -> void:
	display_name = "+Mult per pass"


func get_description() -> String:
	return "+%s mult each time the ball passes %s%s" % [amount, _pocket_name(), _chance_text()]


func apply_pass(_run: RunState, spin: SpinContext) -> void:
	spin.add_mult(amount)


## The mult was already added live during the spin; this only records it.
func modify_score(_run: RunState, ctx: ScoreContext) -> void:
	if _passes == 0:
		return
	ctx.add_trace(self, "+%s mult (%s passes of %s)" % [amount * _passes, _passes, _pocket_name()])
