class_name ConsumableDatabase
extends Resource
## Every consumable the game knows about, and the ones a new run starts with. Edit
## consumable_database.tres in the inspector: drag consumable .tres files into `consumables`, then
## into `starter_consumables` (the same one can be listed more than once). Entries are templates, so
## hand out copies with `create()`.

## Every consumable that can appear in a run (shop stock, rewards, starters).
@export var consumables: Array[Consumable] = []
## What a new run starts with, in order.
@export var starter_consumables: Array[Consumable] = []


## A template picked from `consumables` by the cascading rarity roll on `rng` (use `create()` with
## its `id` for a copy to hand out), skipping any whose id is in `exclude`. Null if none are left.
func roll(rng: RandomNumberGenerator, exclude: Array[Consumable] = []) -> Consumable:
	var excluded_ids := exclude.map(func(item: Consumable) -> StringName: return item.id)
	var candidates := consumables.filter(func(item: Consumable) -> bool: return not excluded_ids.has(item.id))
	return Rarity.roll(rng, candidates) as Consumable


## A fresh copy of the consumable with this `id`, or null if there isn't one.
func create(id: StringName) -> Consumable:
	for item in consumables:
		if item.id == id:
			return item.duplicate(true)
	push_error("No consumable with id '%s' in the consumable database." % id)
	return null


## Fresh copies of the starter consumables.
func create_starters() -> Array[Consumable]:
	var result: Array[Consumable] = []
	for item in starter_consumables:
		result.append(item.duplicate(true))
	return result
