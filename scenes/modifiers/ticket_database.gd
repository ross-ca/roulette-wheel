class_name TicketDatabase
extends Resource
## Every ticket the game knows about, and the ones a new run starts with. Edit
## ticket_database.tres in the inspector: drag ticket .tres files into `tickets`, then into
## `starter_tickets`. Entries are templates, so hand out copies with `create()`.

## Every ticket that can appear in a run (shop stock, rewards, starters).
@export var tickets: Array[Ticket] = []
## What a new run starts with, in order (order is a mechanic).
@export var starter_tickets: Array[Ticket] = []


## A fresh copy of the ticket with this `id`, or null if there isn't one.
func create(id: StringName) -> Ticket:
	for ticket in tickets:
		if ticket.id == id:
			return ticket.duplicate(true)
	push_error("No ticket with id '%s' in the ticket database." % id)
	return null


## Fresh copies of the starter tickets.
func create_starters() -> Array[Ticket]:
	var result: Array[Ticket] = []
	for ticket in starter_tickets:
		result.append(ticket.duplicate(true))
	return result
