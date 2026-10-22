extends Node
## Autoload ("Game"): owns the current run, and starts, saves, loads and ends runs.

const SAVE_PATH := "user://run.tres"
const STARTING_MONEY := 4

var run: RunState
## How the last run ended, for the main menu to show. Empty if no run has ended this session.
var last_result := ""
# False for throwaway runs (a scene run on its own with F6), so they don't overwrite the real save.
var _saving := true


func new_run(rng_seed: int = randi(), saving: bool = true) -> void:
	_saving = saving
	run = RunState.new()
	run.rng_seed = rng_seed
	run.rng.seed = rng_seed
	run.money = STARTING_MONEY
	run.pockets = Pocket.european_layout()
	# Starter tickets until the shop sells them. Swapping their order changes the score.
	var plus_mult := AddMultTicket.new()
	plus_mult.amount = 4.0
	var times_mult := MultiplyMultTicket.new()
	times_mult.factor = 2.0
	run.tickets = [plus_mult, times_mult]


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run() -> void:
	if not _saving:
		return
	run.rng_state = run.rng.state
	var error := ResourceSaver.save(run, SAVE_PATH)
	if error != OK:
		push_error("Couldn't save the run to %s: %s" % [SAVE_PATH, error_string(error)])


## Loads the saved run into `run`. Returns false if there's no usable save.
func load_run() -> bool:
	if not has_save():
		return false
	# Ignore the cache so loading twice in a session gives a fresh copy, not the first one.
	var loaded := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as RunState
	if loaded == null:
		return false
	run = loaded
	_saving = true
	run.rng.seed = run.rng_seed
	run.rng.state = run.rng_state
	return true


func end_run(won: bool) -> void:
	last_result = "You beat every table!" if won else "Run over."
	run = null
	if _saving and has_save():
		DirAccess.remove_absolute(SAVE_PATH)
