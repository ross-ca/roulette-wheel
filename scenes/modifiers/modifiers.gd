class_name Modifiers
extends RefCounted
## Runs the active modifiers in a fixed order: tickets left to right, then the current round's boss
## rules. Game rules go through here; signals are only for UI, sound and animation.
##
## Events passed to `notify` (and on to `Modifier.on_event`), with their args:
## - &"pocket_passed" [pocket, ctx]: the ball entered any pocket. Fires dozens of times a spin, so
##   keep handlers cheap. `ctx` is the spin's live ScoreContext; handlers may change its mult.
## - &"pocket_landed" [pocket]: the ball settled in the winning pocket.
## - &"spin_started" [] / &"spin_finished" [pocket]
## - &"round_started" [round_state] / &"round_finished" [round_state, won]
## - &"step_started" [step] / &"step_finished" [step, result]


static func active(run: RunState) -> Array[Modifier]:
	var list: Array[Modifier] = []
	list.append_array(run.tickets)
	if run.current_step is RoundStep:
		list.append_array(run.current_step.modifiers)
	return list


static func spins_per_round(run: RunState) -> int:
	var spins := run.base_spins_per_round
	for modifier in active(run):
		spins = modifier.modify_spins(run, spins)
	return spins


## Finishes scoring a spin whose context has been live since the spin started (pass events have
## already changed its mult). A lost bet scores nothing, so `modify_score` only runs when the bet won.
static func score(run: RunState, ctx: ScoreContext, pocket: Pocket) -> ScoreContext:
	ctx.land(pocket)
	if ctx.won:
		for modifier in active(run):
			modifier.modify_score(run, ctx)
	return ctx


static func price(run: RunState, base_price: int) -> int:
	var result := base_price
	for modifier in active(run):
		result = modifier.modify_price(run, result)
	return result


static func notify(run: RunState, event: StringName, args: Array = []) -> void:
	for modifier in active(run):
		modifier.on_event(run, event, args)
