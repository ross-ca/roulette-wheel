class_name ShopStep
extends RunStep
## A visit to the shop between rounds.

## How many tickets the shop offers.
const SLOTS := 3
## How many consumables the shop offers, after the tickets.
const CONSUMABLE_SLOTS := 2
## What a reroll costs before modifiers change it. Placeholder: 0 makes rerolls free.
const REROLL_COST := 2

## What the shop is offering, in slot order: the tickets, then the consumables. Kept on the step so
## it's saved with the run: leaving and resuming the shop shows the same stock instead of rolling it again.
@export var stock: Array[Modifier] = []
## True once the stock has been rolled, so a shop that sells out isn't restocked on a reload.
@export var stocked := false


func _init() -> void:
	# load(), not preload(): shop.gd refers back to this class.
	phase_scene = load("res://scenes/shop/shop.tscn")


## Rolls the stock by rarity, one item per slot and none twice, using the run's RNG: tickets from
## `tickets`, then consumables from `consumables`. Does nothing if it's already been rolled. A database
## may have fewer items than slots.
func stock_up(run: RunState, tickets: TicketDatabase, consumables: ConsumableDatabase) -> void:
	if stocked:
		return
	var rolled_tickets: Array[Ticket] = []
	for i in SLOTS:
		var template := tickets.roll(run.rng, rolled_tickets)
		if template == null:
			break
		var ticket := tickets.create(template.id)
		rolled_tickets.append(ticket)
		stock.append(ticket)
	var rolled_consumables: Array[Consumable] = []
	for i in CONSUMABLE_SLOTS:
		var template := consumables.roll(run.rng, rolled_consumables)
		if template == null:
			break
		var consumable := consumables.create(template.id)
		rolled_consumables.append(consumable)
		stock.append(consumable)
	stocked = true


## Throws the stock away and rolls it again.
func reroll(run: RunState, tickets: TicketDatabase, consumables: ConsumableDatabase) -> void:
	stock.clear()
	stocked = false
	stock_up(run, tickets, consumables)
