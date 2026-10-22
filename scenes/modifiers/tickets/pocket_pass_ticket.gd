class_name PocketPassTicket
extends Ticket
## Base for tickets that react every time the ball passes over one pocket. They count the passes
## during a spin; subclasses apply the count to the mult in `modify_score`.

## The number of the pocket to watch.
@export_range(0, 36) var number: int = 0
## The colour it must also be, or "any" to match the number alone. Wheels only have one pocket per
## number so far, but a ticket can still name the colour to be explicit.
@export_enum("any", "red", "black", "green") var colour: String = "any"

## Matching passes in the spin so far. Not saved: saves are never made mid-spin.
var _passes := 0


func on_event(_run: RunState, event: StringName, args: Array) -> void:
	match event:
		&"spin_started":
			_passes = 0
		&"pocket_passed":
			if _matches(args[0]):
				_passes += 1


func _matches(pocket: Pocket) -> bool:
	return pocket.number == number and (colour == "any" or pocket.colour == colour)


func _pocket_name() -> String:
	return str(number) if colour == "any" else "%s %d" % [colour, number]
