# Debugging

## Running a scene on its own

Phase scenes don't need the runner. Open `play.tscn`, `shop.tscn` or `run.tscn` in the editor and press **F6** (Run Current Scene). F5 runs the whole game from the intro; F6 on `main_menu.tscn` skips it.

Each phase checks whether the runner called `setup()` before it entered the tree. If not, it makes its own throwaway run:

```gdscript
# play.gd _ready()
if _run == null:
	Game.new_run(randi(), false)   # false = never saves
	_run = Game.run
	_step = RoundStep.new()        # default target 300
	_run.current_step = _step
```

What you get:

| Scene | With F6 |
| --- | --- |
| `play.tscn` | A fresh round: starter tickets, 4 spins, target 300. At the end it shows the result and emits `finished`, but nothing is listening, so it stays on screen. Press F6 again to replay. |
| `shop.tscn` | The starter tickets and $4. Continue does nothing, for the same reason. |
| `run.tscn` | A full run from the first table, including the pause menu. |

- **Your real save is never touched.** Throwaway runs are created with saving off (`Game.new_run(seed, false)`).
- **No pause menu** in `play.tscn` or `shop.tscn` on their own, because it lives in `run.tscn`. Test pausing with `run.tscn` or F5.
- **Testing a specific situation** (a high target, particular tickets) currently means editing the defaults in that fallback block.

## Adding a new phase scene

Follow the same pattern so it can be run on its own:

1. `setup(run, step)` stores the run and step. It's called before the scene enters the tree, so don't touch child nodes there.
2. `signal finished(result)`, emitted when the phase is done.
3. In `_ready()`, if `setup()` wasn't called, create a throwaway run with `Game.new_run(randi(), false)` and a default step.

## Saves

The save is `user://run.tres`, which on Windows is `%APPDATA%\Godot\app_userdata\roulette-wheel\run.tres`. It's a text resource you can open to inspect a run's state. Delete it to clear Continue.
