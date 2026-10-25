class_name ShopStep
extends RunStep
## A visit to the shop between rounds.

## How many tickets the shop offers.
const SLOTS := 5
## What a reroll costs before modifiers change it. Placeholder: 0 makes rerolls free.
const REROLL_COST := 0

## What the shop is offering, in slot order. Kept on the step so it's saved with the run: leaving
## and resuming the shop shows the same stock instead of rolling it again.
@export var stock: Array[Ticket] = []
## True once the stock has been rolled, so a shop that sells out isn't restocked on a reload.
@export var stocked := false


func _init() -> void:
	# load(), not preload(): shop.gd refers back to this class.
	phase_scene = load("res://scenes/shop/shop.tscn")


## Rolls the stock from `database` by rarity, one ticket per slot and no ticket twice, using the run's
## RNG. Does nothing if it's already been rolled. The database may have fewer tickets than slots.
func stock_up(run: RunState, database: TicketDatabase) -> void:
	if stocked:
		return
	for i in SLOTS:
		var template := database.roll(run.rng, stock)
		if template == null:
			break
		stock.append(database.create(template.id))
	stocked = true


## Throws the stock away and rolls it again.
func reroll(run: RunState, database: TicketDatabase) -> void:
	stock.clear()
	stocked = false
	stock_up(run, database)
