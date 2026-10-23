class_name PassMultiplyMultTicket
extends PocketPassTicket
## Multiplies the mult every time the ball passes over a chosen pocket, so n passes multiply it by
## `factor` to the power of n.

@export var factor: float = 1.5


func _init() -> void:
	display_name = "×Mult per pass"


func get_description() -> String:
	return "×%s mult each time the ball passes %s%s" % [factor, _pocket_name(), _chance_text()]


func apply_pass(_run: RunState, ctx: ScoreContext) -> void:
	ctx.mult *= factor


## The mult was already multiplied live during the spin; this only records it.
func modify_score(_run: RunState, ctx: ScoreContext) -> void:
	if _passes == 0:
		return
	var total := pow(factor, _passes)
	ctx.add_trace(self, "×%s mult (%s passes of %s)" % [total, _passes, _pocket_name()])
