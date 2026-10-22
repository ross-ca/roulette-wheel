# Architecture

How a run is structured, as built. The original proposal, with its reasoning and discussion, is the [Roulette run structure proposal](https://claude.ai/artifact/GGBJfbtG4TACy3CQSebUXR). This file describes what the code does now. See [scene-flow.md](scene-flow.md) for how scenes are loaded and [debugging.md](debugging.md) for running scenes on their own.

## Terms

- **Run**: one attempt, from New run to winning or losing. A series of tables.
- **Table**: a group of rounds with shops between them. Built by `RunGenerator`.
- **Round**: one play phase, a few spins to reach a target score.
- **Ticket**: our version of Balatro's jokers. Order matters.
- **Step**: one entry in the run's queue (a round, a shop, later events and choices).

## The parts

```
Game (autoload)                run.tscn                      phase scenes
┌──────────────────┐  pop   ┌──────────────────────┐ setup  ┌──────────────┐
│ RunState         │──────▶ │ Runner (run.gd)      │──────▶ │ play.tscn    │
│  steps (queue)   │        │  takes the next step │        │ shop.tscn    │
│  tickets,pockets │        │  awaits finished     │◀────── │ (events...)  │
│  money, round    │        │  saves after each    │ result └──────┬───────┘
│  seeded rng      │        ├──────────────────────┤               │ spins, score,
└────────▲─────────┘        │ PauseMenu            │               ▼ prices
         │ refills          └──────────────────────┘        ┌──────────────┐
┌────────┴─────────┐                                        │ Modifiers    │
│ RunGenerator     │                                        │ tickets, then│
│ next_table()     │                                        │ boss rules   │
└──────────────────┘                                        └──────────────┘
```

## Run data: `RunState`

`scenes/game/run_state.gd`. A Resource holding everything that outlives a phase, held by the `Game` autoload as `Game.run`. Scenes read and change it but never own it.

Rules:

1. **Everything that must survive a save is an `@export`.** The run is saved whole with `ResourceSaver`.
2. **Effects never overwrite base values.** `base_spins_per_round` stays as it is; the effective value comes from `Modifiers.spins_per_round(run)` each time. Selling or reordering a ticket can't corrupt the run.
3. **All gameplay randomness goes through `run.rng`.** It's seeded from `rng_seed`, and its state is saved, so a reloaded run rolls the same next spin (no re-rolling a bad spin by quitting).

## Pockets

`scenes/wheel/pocket.gd`. Each pocket is a `Pocket` Resource (`number`, `colour`, `weight`), because pockets are a core feature that will gain many properties.

- They belong to `run.pockets`. The play phase hands them to the wheel with `set_pockets()`.
- `Pocket.european_layout()` returns a fresh set of 37 every call, so runs never share pocket objects.
- Properties the wheel draws emit `changed`, and the wheel redraws when any of its pockets change.
- Refer to a particular pocket by object, not index. Indexes shift when pockets are added, removed or reordered.
- The winner is picked at spin start using `weight`, so weight changes during a spin only affect the next one.

## Bets

`scenes/bets/`. Before each spin the player chooses a chip amount and a **bet**: the outcome they're backing. A `Bet` Resource has a `display_name`, a `base_mult` and `wins(pocket) -> bool`.

- **Base mult comes from the odds.** It is 36 divided by the numbers the bet covers: red or black (18 numbers) is ×2, a single number (zero included) is ×36, a dozen (12) would be ×3. Rarer outcomes pay more. Each subclass sets its own value.
- **Losing scores nothing.** If the landed pocket doesn't satisfy the bet, the spin scores 0 and `modify_score` isn't called, so tickets only trigger on a win. (Zero is green, so it loses every red or black bet.)
- `ColourBet` covers red, black (×2) and green (×36, since green is only zero), and sets `base_mult` from its `colour`. `NumberBet` is one exact number from 0 to 36, also ×36.
- The HUD offers the colours as toggle buttons and the number as a text field. Entering a number picks a `NumberBet` and disables the colour buttons; clearing the field enables them again. Further bets, such as odd/even, dozens and columns, are new `Bet` subclasses; the HUD chooses which are offered.
- The chips and bet are read from the HUD when Spin is pressed and held by `play.gd` until the spin settles. Both inputs are locked during the spin. They aren't saved, so a resumed round starts with the HUD defaults (10 chips, red).

## Steps and the queue

`scenes/run/steps/`. A run is a queue of `RunStep` Resources in `run.steps`. Each step names the scene that plays it (`phase_scene`) and handles its own outcome in `on_finished(run, result)`.

- `RoundStep`: `target_score`, `reward`, and `modifiers` (boss rules). Winning pays the reward; losing ends the run.
- `ShopStep`: a shop visit.

Branching is editing the queue: skip a round with `pop_front()`, insert an event step, make a boss round by giving a `RoundStep` modifiers. Steps loaded from `.tres` files are shared by Godot's resource cache, so `duplicate(true)` them before queuing.

`RunGenerator.next_table(run)` builds each table's steps; layout and difficulty live there. It returns an empty array when every table is done, which means the run is won. It currently builds one table: round, shop, round.

## The runner

`scenes/run/run.gd`. Plays steps one at a time with `await` until `run.is_over` or the generator runs out. It doesn't know what kind of step it's running.

Every phase scene follows the same contract:

- `setup(run, step)`, called before the scene enters the tree.
- `signal finished(result)`, emitted when it's done.

A phase never decides what comes next.

## Modifiers, tickets and triggers

`scenes/modifiers/`. Tickets, boss rules and any other rule-bending effect extend `Modifier` and override only the hooks they need:

| Hook | Use |
| --- | --- |
| `modify_spins(run, spins) -> int` | Spins per round |
| `modify_score(run, ctx)` | Change the `ScoreContext` for a spin |
| `modify_price(run, price) -> int` | Shop prices |
| `on_event(run, event, args)` | React to something that happened |

`Modifiers` (static) runs them in a fixed order: tickets in `run.tickets` order, then the current round's boss rules. **Game rules go through this loop; signals are only for UI, sound and animation**, because signal order is hidden and the trigger order is a gameplay mechanic.

Events, raised with `Modifiers.notify(run, event, args)`:

| Event | When | Args |
| --- | --- | --- |
| `pocket_passed` | The ball enters any pocket (dozens per spin, keep handlers cheap) | pocket |
| `pocket_landed` | The ball settles | pocket |
| `spin_started` / `spin_finished` | Each spin | — / pocket |
| `round_started` / `round_finished` | Each round | round state / round state, won |
| `step_started` / `step_finished` | Every step | step / step, result |

`step_started` only fires when a step is first taken, not when a save resumes it.

**Tickets that count passes.** `PocketPassTicket` watches one pocket (`number`, optionally `colour`). It resets its count on `spin_started`, adds one for each matching `pocket_passed`, and its subclasses apply the count in `modify_score`: `PassAddMultTicket` adds `amount × passes` to the mult, `PassMultiplyMultTicket` multiplies it by `factor ^ passes`. The count is plain per-spin state, not saved, because saves are never made mid-spin. Since `modify_score` only runs on a winning bet, a lost spin ignores the passes.

### Scoring (placeholder)

`ScoreContext` starts with `points` as the chips the player submitted (the HUD's `ChipsInput`) and `mult` as the bet's `base_mult`. If the bet won it passes through every modifier and totals `points × mult`; if it lost the total is 0 and no modifier runs. The real formula (probably points × mult plus per-pocket bonuses) isn't designed yet; only `ScoreContext` and the play phase should change when it is.

Modifiers record what they did in `ctx.trace`. Rules are computed instantly and the HUD plays the trace back afterwards, so game logic never waits on animation.

## Saving

`Game.save_run()` writes `user://run.tres`.

- **When:** after every spin settles, at the start of a round, and after every step. Never mid-spin.
- **Mid-round:** progress (`spins_left`, `score`, `money_earned`) lives in `run.current_round` (`RoundState`), not in `play.gd`, so it's saved with the run.
- **Resume:** Continue loads the save; the runner replays `current_step`, and the play phase picks up `current_round`.
- **End:** `Game.end_run()` deletes the save.
- **Caveat:** a `.tres` file can contain scripts, so loading an untrusted one can run code. Fine while saves stay on the player's machine; switch to JSON if saves are ever shared.

## Pausing

`scenes/pause_menu/`. Esc (`ui_cancel`) toggles `get_tree().paused`. The pause menu lives in `run.tscn` with Process Mode **Always**, so it hears Esc while the game runs (When Paused would never see the Esc that pauses it). Everything else is Pausable: the wheel's tweens freeze mid-spin and the runner's `await` simply waits.

## Decisions and open questions

| Topic | Decision |
| --- | --- |
| Pocket data | `Pocket` Resource |
| Scoring | Chips × (bet's base mult plus modifiers); a lost bet scores 0. Placeholder for now |
| Bets | `Bet` Resource; base mult = 36 / numbers covered; red/black first |
| Triggers | All levels: pocket passed, landed, spin, round, step |
| Saving | Includes part-way through a round, saved after every spin |
| Ticket order | Matters; `run.tickets` order is the trigger order |

Still open:

- Linear queue or a branching map?
- Boss rules before or after tickets in the trigger order? (Currently after.)
- Should anything be able to change where the current ball lands? Today the winner is fixed at spin start.
- The scoring formula.
- What the shop sells besides tickets.

## Next

The real shop, boss rounds, skips and events, and more bet types.
