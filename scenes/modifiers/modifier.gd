class_name Modifier
extends Resource
## Base for anything that bends the rules: tickets, boss rules and other effects. Subclasses
## override only the hooks they need. `Modifiers` calls them in order on every active modifier.
##
## A modifier is the thing itself: it owns its data and behaviour, lives in the RunState and is saved
## with it. It never knows how it's shown. A `Card` (and its tooltip) is only a view of it, built
## from `display_name`, `icon`, `get_description()` and `get_kind_name()`, and listening to
## `triggered`.

## Emitted when the modifier does something worth showing, e.g. for its card to pulse. UI only: the
## effect itself has already happened by the time this fires.
signal triggered

@export var display_name: String = ""
@export var icon: Texture2D


## What the modifier does, with its current values filled in, for its tooltip. Subclasses override
## this so the numbers come from the same fields the hooks use. May contain BBCode.
func get_description() -> String:
	return ""


## What kind of thing this is, shown on its tooltip, e.g. "Ticket". Empty shows nothing.
func get_kind_name() -> String:
	return ""


## Value hooks: take the value so far and return the new one. `modify_score` runs once for each bet
## that won, with that bet's ScoreContext.
func modify_spins(_run: RunState, spins: int) -> int:
	return spins


func modify_score(_run: RunState, _ctx: ScoreContext) -> void:
	pass


func modify_price(_run: RunState, price: int) -> int:
	return price


## Event hook: react to something that happened. See `Modifiers` for the event names.
func on_event(_run: RunState, _event: StringName, _args: Array) -> void:
	pass
