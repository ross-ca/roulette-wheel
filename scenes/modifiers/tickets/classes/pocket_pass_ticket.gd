class_name PocketPassTicket
extends Ticket
## Base for tickets that react every time the ball passes over one pocket. Subclasses override
## `apply_pass` to change the spin's live mults as each pass happens; the base counts the passes so
## `modify_score` can trace the total afterwards.

## The number of the pocket to watch.
@export_range(0, 36) var number: int = 0
## The colour it must also be, or "any" to match the number alone. Wheels only have one pocket per
## number so far, but a ticket can still name the colour to be explicit.
@export_enum("any", "red", "black", "green") var colour: String = "any"

## Chance that a matching pass triggers the ticket: 0 never, 1 every pass.
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 1.0

## Triggered passes in the spin so far. Not saved: saves are never made mid-spin.
var _passes := 0


func on_event(run: RunState, event: StringName, args: Array) -> void:
	match event:
		&"spin_started":
			_passes = 0
		&"pocket_passed":
			if _matches(args[0]) and _rolls_trigger(run):
				_passes += 1
				apply_pass(run, args[1])
				triggered.emit()


## Called on each matching pass with the run and the spin's live SpinContext.
func apply_pass(_run: RunState, _spin: SpinContext) -> void:
	pass


# Uses the run's rng, like all gameplay randomness. Skips the roll at 1 so it doesn't consume rng.
func _rolls_trigger(run: RunState) -> bool:
	return trigger_chance >= 1.0 or run.rng.randf() < trigger_chance


func _matches(pocket: Pocket) -> bool:
	return pocket.number == number and (colour == "any" or pocket.colour == colour)


## For descriptions: " (50% chance)", or nothing when it always triggers.
func _chance_text() -> String:
	return "" if trigger_chance >= 1.0 else " (%d%% chance)" % roundi(trigger_chance * 100.0)


func _pocket_name() -> String:
	return str(number) if colour == "any" else "%s %d" % [colour, number]
