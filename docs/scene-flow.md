# Scene flow

How scenes get loaded and used, from launch to the end of a run. See [architecture.md](architecture.md) for the systems behind them.

## Launch

1. Godot creates the autoloads first, `Audio`, `Game` and `Tooltip`. They sit under the root for the whole session and are never unloaded.
2. It loads the main scene set in `project.godot`: `scenes/intro/intro.tscn`, the intro video. It starts loading the main menu in the background, plays the intro video (`VideoStreamPlayer`, Ogg Theora, letterboxed to its aspect ratio), and changes to the menu when the video ends or on any key, click or button press. With no video set it goes straight to the menu.

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

- `play.tscn` is one round. It holds a SubViewport with the `RouletteWheel` scene, the two views (`BettingView` and `WheelView`, which slide between each other without being freed), the shared ticket strip and the HUD overlay. It reads and writes `Game.run.current_round`.
- `shop.tscn` is the stub shop. It shows `ShopStep.stock` (five tickets rolled by rarity, kept on the step so a reload shows the same ones) in a `CardContainer`; a Reroll button re-rolls them for a price; it can't buy them yet.

Each emits `finished(result)` when done, which wakes the loop.

## Inside the play phase

`play.tscn` has two screens, betting and the wheel, and the player switches between them often. Both are loaded for the whole round. Switching never loads, frees or hides anything, and never moves a camera or the viewport. It slides the two views themselves.

```
Play (play.gd)
├─ SubViewport
│   └─ RouletteWheel        renders off screen into the viewport's texture
├─ Views                    screen-sized, clip_contents on
│   ├─ BettingView          screen-sized
│   └─ WheelView            screen-sized; its WheelOutput shows the SubViewport's texture
├─ CardContainer            the ticket strip, shared by both views
└─ HUD                      CanvasLayer overlay: result, Continue, pass popups
```

**The slide.** `play.gd` keeps one number, `_view_position`: 0 shows betting, 1 shows the wheel, and values between are part-way through a slide. Every frame `_place_views()` lays the views out from it, with `w` the screen width:

- `BettingView.position.x = -_view_position × w`, moving from on screen off to the left.
- `WheelView.position.x = (1 - _view_position) × w`, moving from off to the right onto the screen.

So the views always sit side by side, and `Views` clips whatever is off screen, which therefore isn't drawn. The buttons call `_show_view()`, which tweens `_view_position` to 0 or 1 over `SLIDE_DURATION`. It kills any slide already running first, so pressing the other button mid-slide turns it round from where it is. Since the layout is recomputed every frame, window resizes are handled too.

**The tickets** don't belong to either view. Each view has an empty `ticket_slot` Control marking where they go, and `_place_views()` puts `CardContainer` the same fraction of the way from the betting view's slot to the wheel view's. It glides between them as the views slide, and there's only ever one strip to keep in sync with `run.tickets`.

**The wheel** lives in the SubViewport, not in `WheelView`, so it renders and keeps spinning whichever view is showing. `play.gd` hands the viewport's texture to `WheelView.set_wheel_texture()`.

**Why not separate scenes or a camera.** Separate scenes would be freed on every switch, losing the wheel mid-spin, and couldn't animate between each other. A `Camera2D` would move the whole canvas, so the tickets couldn't take their own path. Moving two plain Controls keeps each view an ordinary full-screen layout you can edit on its own. Keeping both loaded costs little: the hidden one is clipped and its scripts are idle.

**Who decides what.** The views are display only. They emit signals (connected in `play.tscn`) and expose `show_*` methods; `play.gd` holds every rule, including that the player can't go back to betting while the wheel spins.

## Pausing and quitting

Esc sets `get_tree().paused`. Everything freezes except `PauseMenu`, which is set to Process Mode Always. **Quit to menu** unpauses, then calls `change_scene_to_file("main_menu.tscn")`, which frees the whole run scene, waiting loop included. The save on disk is from the last spin that settled or bet that changed.

## Run end

The loop calls `Game.end_run()`, which deletes the save and records the result, then changes scene to the main menu, which shows that result.

## The tree at any moment

```
root
├─ Audio          (autoload)
├─ Game           (autoload, holds Game.run)
├─ Tooltip        (autoload, the shared card tooltip)
└─ Intro  or  MainMenu  or  Run
                  ├─ Phase
                  │   └─ Play  or  Shop   (swapped by the loop)
                  └─ PauseMenu
```

The data lives in `Game.run`; scenes only display and change it. That's why phases can be freed and swapped freely, and why saving the run is enough to resume.
