class_name RunGenerator
extends RefCounted
## Builds each table's steps. The layout of a table and the difficulty curve live here, so the
## runner stays generic.

const TABLE_COUNT := 1
const ROUNDS_PER_TABLE := 2


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
	var step := RoundStep.new()
	match index:
		0:
			step.target_score = 300 * table
		_:
			step.target_score = 500 * table
			step.reward = 5
	return step
