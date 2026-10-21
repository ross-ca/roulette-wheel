# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.7 (Forward Plus, Jolt Physics) 2D roulette roguelike in the style of Balatro, pure GDScript. There is no build system, linter or test suite; develop by opening the project in the Godot editor, or run it with `godot --path .` (main scene is `scenes/main_menu/main_menu.tscn`). `.vscode/settings.json` points godot-tools at a Windows editor path, so adjust it locally if needed. Indentation is tabs (GDScript default).

Prose docs live in `docs/` (it has a `.gdignore`, so Godot doesn't import it): `architecture.md` (the design as built, decisions and open questions), `scene-flow.md` (how scenes are loaded and swapped) and `debugging.md` (running scenes on their own, saves). Keep them in sync when changing those systems. The original proposal is the "Roulette run structure proposal" doc (https://claude.ai/artifact/GGBJfbtG4TACy3CQSebUXR). Terms: a **run** is a series of **tables**, each table has several **rounds** (a play phase of a few spins) with a **shop** between them, and **tickets** are our version of Balatro's jokers.

## Architecture

Scenes live in `scenes/<name>/` with their script alongside.

### Run structure

- **Game** autoload (`scenes/game/game.gd`) holds the current run as `Game.run` and starts, saves (`user://run.tres`), loads and ends runs. `new_run(seed, false)` makes a throwaway run that never saves; scenes use it when run on their own (F6) so they don't overwrite the real save. The editor only picks up autoload changes made outside it after Project → Reload Current Project.
- **RunState** (`scenes/game/run_state.gd`) is a Resource holding everything that outlives a phase: money, tickets, pockets, the step queue, the current step and round, and a seeded `rng`. It's saved whole with `ResourceSaver`, so anything that must survive a save is an `@export`. `rng.state` is copied into `rng_state` on save. All gameplay randomness goes through `run.rng`.
- **Base values are never overwritten by effects.** Effective values (spins per round, score, prices) are computed through `Modifiers` each time.
- **Steps** (`scenes/run/steps/`): a run is a queue of `RunStep` Resources (`RoundStep`, `ShopStep`). Each names its `phase_scene` and handles its own outcome in `on_finished`. Steps loaded from `.tres` are shared by the resource cache, so `duplicate(true)` them before queuing.
- **Runner** (`scenes/run/run.gd`, `run.tscn`) plays steps one at a time with `await`, saving after each. It resumes `current_step` if a loaded save has one. `RunGenerator.next_table()` builds each table's steps (layout and difficulty live there); an empty result means the run is won.
- **Phase contract**: every phase scene has `setup(run, step)`, called before it enters the tree, and `signal finished(result)`. Phases never decide what comes next.
- **Modifiers** (`scenes/modifiers/`): tickets (`Ticket`), boss rules and other effects extend `Modifier` and override only the hooks they need (`modify_spins`, `modify_score`, `modify_price`, `on_event`). `Modifiers` (static) runs them in a fixed order: tickets in `run.tickets` order (order is a mechanic), then the current `RoundStep.modifiers`. Game rules go through this loop; signals are only for UI, sound and animation. Event names and args are listed at the top of `modifiers.gd`.
- **Scoring** is a placeholder: `ScoreContext` carries `points × mult` through the modifiers, starting from the pocket's `base_points`, and records a `trace` for the HUD to play back.
- **Pause menu** (`scenes/pause_menu/`) lives in `run.tscn` with Process Mode Always so it hears Esc while unpaused; everything else in the run is Pausable.

### Play phase

`scenes/play/play.tscn` is one round. Round progress (`spins_left`, `score`, `money_earned`) lives in `run.current_round` (`RoundState`), not in `play.gd`, so it's saved after every settled spin and a save resumes mid-round.

- **HUD** (`CanvasLayer`) emits `spin_requested` when the spin button is pressed; `play.gd` handles it (connected in `play.tscn`). `hud.gd` shows round info, the last spin's score breakdown and the result, plus `show_pass(pocket)`, a throwaway visualisation that pops the passed number in the right third of the screen and fades it out.
- **Audio** is an autoload singleton (`Audio`, `scenes/audio/audio.gd`): a pool of 8 `AudioStreamPlayer`s behind `Audio.play_sfx(stream, volume_db, pitch_scale)`.
- **Wheel is rendered via a SubViewport**: `RouletteWheel` is instanced inside `Play/SubViewport`, and the `WheelViewportOutput` Sprite2D in `Play` displays that viewport's texture. `wheelShader.gdshader` is applied to that sprite. It adds a drop shadow (cast from pixels that differ from `background_color`) and a vertical "bob" effect, so the wheel's transparent background must match the shader's `background_color`. Both `play.gd` and `wheel_behaviour.gd` centre themselves on the viewport size.
- **RouletteWheel** (`wheel_behaviour.gd`, root) owns the spin, guarded by `is_spinning`. See "Spin and ball" below. `play.gd` gives it the run's pockets (`set_pockets`) and RNG (`rng`). It emits `pocket_passed(index, pocket)` for every pocket the ball enters (including the landing one) and `spin_finished(index, pocket)` when everything has settled. Passes drive the HUD popup and the tick sound, which is rate-limited (35ms) with a pitch that rises per tick played in the spin; modifiers get every pass through `Modifiers.notify`, not the rate-limited sound.
- **Pockets** are `Pocket` Resources (`scenes/wheel/pocket.gd`: `number`, `colour`, `weight`, `base_points`), owned by `run.pockets`. `Pocket.european_layout()` returns a fresh set each call. Refer to a particular pocket by object, not index, since indexes shift when pockets change.
- **WheelVisual** (`draw_wheel.gd`) is a `@tool` node that draws the wheel entirely in `_draw()`: segments are polygons, with optional UV-mapped `segment_texture` (`texture_coverage` controls horizontal span), plus borders, rotated number labels and the hub. Pocket 0 starts at the top (-PI/2) and goes clockwise, in `pockets` array order. Its `pockets` defaults to the European layout so it previews in the editor. Colours come from the `COLOURS` constant, keyed by `Pocket.colour`.

### Spin and ball (`wheel_behaviour.gd`)

- **The winner is chosen first**, by `pick_winning_index()`, using each pocket's `weight` (0 means it can never win). The animation is then built to land the ball on that pocket, so mutating pockets (add, remove, reorder, reweight) just works. Don't change pockets mid-spin: targets are computed at spin start, so weight changes only affect the next spin.
- **The ball's angle is relative to the wheel** (`_ball_angle`), and the ball sprite is positioned each frame at `wheel.rotation + _ball_angle`. Once the relative angle stops changing the ball rides the wheel for free, and the wheel's own rotation never affects where it lands. The target angle uses `fposmod` to pick the shortest gap to the pocket, then adds `ball_turns` laps. `ball_turns` is the wheel's turns plus a few extra so the ball runs against the wheel in world space.
- **Pass detection** counts an unwrapped step (`_ball_step()`) and steps through every pocket crossed since last frame, because the ball crosses several pockets per frame early on.
- **Tween timeline**: wheel windup (pulls back against the spin), then the ball launches. Ball angle (quint ease-out, `spin_duration`) and ball radius (out to the rim, wait, then drop to the hub with `TRANS_BOUNCE`) are separate tweens. The wheel's spin is one continuous curve in `_set_wheel_spin` (ease-out to slightly past the target, then eased back onto it) that finishes when the ball stops bouncing (`ball_drop_time + ball_drop_duration`), so it is not driven by `spin_duration`. The ease-out ends at zero velocity exactly where the return starts. A high `wheel_ease_power` makes the wheel look stopped for a moment before the return.
- Timings, turn ranges (`wheel_turns_*`, `ball_extra_turns_*`), radii, windup and overshoot are all exports on the root node. `debug_freeze_wheel` skips the wheel tween so only the ball moves.

### `draw_wheel.gd` redraw mechanism

Exported properties in `_DRAW_PROPERTIES` trigger `queue_redraw()` through a custom `_set()` override, so edits in the inspector update live in the editor. When adding a new exported property that affects drawing, add it to `_DRAW_PROPERTIES`. The override deliberately ignores sets while not in the tree (the scene entering the tree redraws once), and uses `_setting_draw_property` to avoid recursion. `pockets` isn't exported: its setter redraws, and connects to each pocket's `changed` signal so editing a pocket redraws too.

## Conventions

- Assets go in `assets/` (`fonts`, `textures`, `audio/{music,sfx}`); `addons/` is currently empty.
- Commit the `.uid` files Godot generates next to scripts and shaders. Don't commit `.godot/`.
