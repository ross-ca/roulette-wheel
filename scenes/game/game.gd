extends Node
## Autoload ("Game"): owns the current run, and starts, saves, loads and ends runs.

const SAVE_PATH := "user://run.tres"
const STARTING_MONEY := 200
const STARTING_VOUCHERS := 0
## Shown in front of a voucher amount, in place of a currency character. Used through `voucher_text`.
const VOUCHER_SYMBOL := "res://assets/textures/voucherSymbol.png"
## Height in pixels the symbol is drawn at in a RichTextLabel; the shop's font is 28.
const VOUCHER_SYMBOL_HEIGHT := 18
## Where the symbol sits against the text, "image,text". Bottom on the baseline lines it up with the
## digits; the default, center,center, centres it on the line box, which sits above a pixel font's digits.
const VOUCHER_SYMBOL_ALIGN := "bottom,baseline"
const TICKET_DATABASE := preload("res://scenes/modifiers/ticket_database.tres")
const CONSUMABLE_DATABASE := preload("res://scenes/modifiers/consumable_database.tres")

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
	run.vouchers = STARTING_VOUCHERS
	run.pockets = Pocket.european_layout()
	run.tickets = TICKET_DATABASE.create_starters()
	run.consumables = CONSUMABLE_DATABASE.create_starters()


## BBCode for an amount of vouchers: the symbol, then the number. For RichTextLabels only; Labels and
## Buttons can't show it.
static func voucher_text(amount: int) -> String:
	return "[img height=%d align=%s]%s[/img]%d" % [
		VOUCHER_SYMBOL_HEIGHT, VOUCHER_SYMBOL_ALIGN, VOUCHER_SYMBOL, amount
	]


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
