class_name Ticket
extends Modifier
## Our version of jokers. The player holds them in `RunState.tickets`, and their order there is the
## order they trigger in.

## Stable name used to look the ticket up in the TicketDatabase.
@export var id: StringName = &""
@export var price: int = 4


func get_kind_name() -> String:
	return "Ticket"
