class_name Modifier
extends Resource
## Base for anything that bends the rules: tickets, boss rules and other effects. Subclasses
## override only the hooks they need. `Modifiers` calls them in order on every active modifier.

@export var display_name: String = ""
@export var icon: Texture2D


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
