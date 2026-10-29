class_name RunGenerator
extends RefCounted
## Builds each table's steps. The layout of a table and the difficulty curve live here, so the
## runner stays generic.

const TABLE_COUNT := 2
const ROUNDS_PER_TABLE := 4
const BASE_REQUIRED_PROFIT := 300


## Starts the next table and returns its steps, or an empty array once every table is done.
static func next_table(run: RunState) -> Array[RunStep]:
	var steps: Array[RunStep] = []
	if run.table >= TABLE_COUNT:
		return steps

	# A new table starts with the last round of the previous one's required profit as money; any
	# surplus is dropped (it will convert into vouchers later).
	if run.table > 0:
		run.money = _round(run.table, ROUNDS_PER_TABLE - 1).required_profit
	run.table += 1
	for i in ROUNDS_PER_TABLE:
		if i > 0 or run.table > 1:
			steps.append(ShopStep.new())
		steps.append(_round(run.table, i))
	return steps


static func _round(table: int, index: int) -> RoundStep:
	if (index == ROUNDS_PER_TABLE - 1):
		return _boss_round(table)
	
	var step := RoundStep.new()
	var current_round := (table - 1) * ROUNDS_PER_TABLE + index
	step.required_profit = (2 ** current_round) * BASE_REQUIRED_PROFIT

	return step

static func _boss_round(table: int) -> RoundStep:
	var step := RoundStep.new()
	var current_round := (table - 1) * ROUNDS_PER_TABLE + ROUNDS_PER_TABLE - 1
	step.required_profit = (2 ** current_round) * BASE_REQUIRED_PROFIT * 1.5 # Placeholder x1.5 for boss round

	return step
