class_name Ticket
extends Modifier
## Our version of jokers. The player holds them in `RunState.tickets`, and their order there is the
## order they trigger in.

## Stable name used to look the ticket up in the TicketDatabase.
@export var id: StringName = &""
@export var price: int = 4


## What the ticket does, with its current values filled in. Subclasses override this so the
## numbers come from the same fields the hooks use.
func get_description() -> String:
	return ""
