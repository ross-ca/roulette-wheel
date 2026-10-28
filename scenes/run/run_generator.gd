class_name RunGenerator
extends RefCounted
## Builds each table's steps. The layout of a table and the difficulty curve live here, so the
## runner stays generic.

const TABLE_COUNT := 2
const ROUNDS_PER_TABLE := 4
const BASE_TARGET_SCORE := 300


## Starts the next table and returns its steps, or an empty array once every table is done.
static func next_table(run: RunState) -> Array[RunStep]:
	var steps: Array[RunStep] = []
	if run.table >= TABLE_COUNT:
		return steps

	run.table += 1
	for i in ROUNDS_PER_TABLE:
		if i > 0:
			steps.append(ShopStep.new())
		steps.append(_round(run.table, i))
	return steps


static func _round(table: int, index: int) -> RoundStep:
	if (index == ROUNDS_PER_TABLE - 1):
		return _boss_round(table)
	
	var step := RoundStep.new()
	var current_round := (table - 1) * ROUNDS_PER_TABLE + index
	step.target_score = (2 ** current_round) * BASE_TARGET_SCORE
	step.reward = 3

	return step

static func _boss_round(table: int) -> RoundStep:
	var step := RoundStep.new()
	var current_round := (table - 1) * ROUNDS_PER_TABLE + ROUNDS_PER_TABLE - 1
	step.target_score = (2 ** current_round) * BASE_TARGET_SCORE * 1.5 # Placeholder x1.5 for boss round
	step.reward = 5

	return step
