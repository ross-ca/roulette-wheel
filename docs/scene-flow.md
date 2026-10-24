# Scene flow

How scenes get loaded and used, from launch to the end of a run. See [architecture.md](architecture.md) for the systems behind them.

## Launch

1. Godot creates the autoloads first, `Audio`, `Game` and `Tooltip`. They sit under the root for the whole session and are never unloaded.
2. It loads the main scene set in `project.godot`: `scenes/main_menu/main_menu.tscn`.

## Main menu

- **New run** calls `Game.new_run()`, which builds a fresh `RunState` in memory.
- **Continue** calls `Game.load_run()`, which reads `user://run.tres` back into `Game.run`.
- Either way it then calls `change_scene_to_file("run.tscn")`, which frees the menu and loads the run scene in its place.

## Run scene

`run.tscn` stays loaded for the whole run. It has two children: `Phase` (an empty node that holds the active phase) and `PauseMenu` (always present, hidden until Esc).

Its `_ready()` starts the loop in `run.gd`, which repeats:

1. Take the next step from `Game.run.steps`, or resume `current_step` if a save had one. If the queue is empty, ask `RunGenerator` for the next table.
2. Instantiate the step's `phase_scene` (`play.tscn` or `shop.tscn`).
3. Call `phase.setup(run, step)`, then `add_child` it under `Phase`. Its `_ready()` runs now.
4. `await phase.finished`. The loop sleeps here while the player plays.
5. `queue_free()` the phase, call `step.on_finished()`, save, and go back to 1.

## Phase scenes

- `play.tscn` is one round: the HUD, a SubViewport with the `RouletteWheel` scene, and the sprite that displays the viewport. It reads and writes `Game.run.current_round`.
- `shop.tscn` is the stub shop.

Each emits `finished(result)` when done, which wakes the loop.

## Pausing and quitting

Esc sets `get_tree().paused`. Everything freezes except `PauseMenu`, which is set to Process Mode Always. **Quit to menu** unpauses, then calls `change_scene_to_file("main_menu.tscn")`, which frees the whole run scene, waiting loop included. The save on disk is from the last spin that settled.

## Run end

The loop calls `Game.end_run()`, which deletes the save and records the result, then changes scene to the main menu, which shows that result.

## The tree at any moment

```
root
├─ Audio          (autoload)
├─ Game           (autoload, holds Game.run)
└─ MainMenu  or  Run
                  ├─ Phase
                  │   └─ Play  or  Shop   (swapped by the loop)
                  └─ PauseMenu
```

The data lives in `Game.run`; scenes only display and change it. That's why phases can be freed and swapped freely, and why saving the run is enough to resume.
