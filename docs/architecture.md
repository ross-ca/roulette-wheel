# Architecture

How a run is structured, as built. The original proposal, with its reasoning and discussion, is the [Roulette run structure proposal](https://claude.ai/artifact/GGBJfbtG4TACy3CQSebUXR). This file describes what the code does now. See [scene-flow.md](scene-flow.md) for how scenes are loaded and [debugging.md](debugging.md) for running scenes on their own.

## Terms

- **Run**: one attempt, from New run to winning or losing. A series of tables.
- **Table**: a group of rounds with shops between them. Built by `RunGenerator`.
- **Round**: one play phase, a few spins to reach a target score.
- **Ticket**: our version of Balatro's jokers. Order matters.
- **Step**: one entry in the run's queue (a round, a shop, later events and choices).
- **Card**: how something the player holds or can buy is shown on screen. A view, not the thing itself.

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

`scenes/bets/`. Before each spin the player drags chips onto the table to place one or more **bets**: the outcomes they're backing. A `Bet` Resource has a `display_name`, a `base_mult`, `wins(pocket) -> bool` and `key()`, which identifies the outcome so two bet objects on the same spot count as the same bet.

- **Base mult comes from the odds.** It is 36 divided by the numbers the bet covers: red or black (18 numbers) is ×2, a single number (zero included) is ×36, a dozen (12) would be ×3. Rarer outcomes pay more. Each subclass sets its own value.
- **Losing scores nothing.** If the landed pocket doesn't satisfy a bet, that bet scores 0 and `modify_score` isn't called for it, so tickets only trigger on a win. (Zero is green, so it loses every red or black bet.)
- `ColourBet` covers red, black (×2) and green (×36, since green is only zero), and sets `base_mult` from its `colour`. `NumberBet` is one exact number from 0 to 36, also ×36. `DozenBet` is 1-12, 13-24 or 25-36 (×3); zero is in no dozen. `ParityBet` is even or odd and `HalfBet` 1-18 or 19-36, both ×2; zero loses both.
- **Placed bets** are `PlacedBet` Resources (`bet`, and `chips` in the order they were dropped) in `run.current_round.bets`, so they're saved: the round is saved after every bet change. A chip dropped on a spot that already has a bet joins its chips (matched by `key()`); right-clicking a spot removes its bet. `PlacedBet.total()` is what the bet stakes. A spin needs at least one bet and uses them all up, so the table is empty after each spin.
- **Each chip is remembered**, as a `PlacedChip` Resource (`value`, `tier`), not folded into a total. The table then shows the chips actually dropped, even once chip values follow the player's money, and chips can gain properties of their own later (special chips would be fields or subclasses here).
- **The table** (`scenes/bet_table/`) is a `BetTable`, a custom Container in `BettingView`. It makes a `BetSpot` (`bet_spot.tscn`: a drop target holding its `Bet`) for each place to bet and lays them out on a grid of 13 columns: zero down the left across the three number rows (half a tile wide), the numbers in three rows of twelve (3, 6, 9… along the top), the three dozens below them (four columns each) and the even-money bets along the bottom in a real table's order, 1-18, even, red, black, odd, 19-36 (two columns each). Further bets, such as columns, are new `Bet` subclasses plus `_add_spot` calls giving their starting cell and how many columns and rows they span (`column_span`, `row_span`).
- **Square tiles that scale.** Every layout pass (`_layout`, on `NOTIFICATION_SORT_CHILDREN`, so on every resize) picks the largest tile that fits the space across and down, scaled by the `fill` export (0.9 in the betting view, so the table leaves some room around it), makes number tiles that square, zero's column `ZERO_COLUMN_WIDTH` (a const, 0.5) of a tile wide and the dozens and colours rows `outside_row_height` of a tile tall, centres the grid, and places each spot with `fit_child_in_rect`. It works out each column's left edge and width, and each row's top and height, then sizes a spot from the first and last column and row it covers, so a spot spanning a narrow column or row comes out right. On a 1920×1080 window a tile comes out at about 146 screen pixels, slightly over the 141.5 the design was drawn at, and the height is now the limit (just), leaving about 8 base pixels either side of the grid.
- **Styling** lives in a `TableStyle` Resource (`scenes/bet_table/table_style.tres`), not in textures, so it can change at run time. It holds one `BetTileStyle` (fill, label colour, shadow colour and offset, and an optional `font` and `font_size` that override the table's for that kind of tile) per pocket colour in `tiles` (red, black, green), plus `outside` for the dozens and the even-money bets, and `fallback` for a colour it doesn't know, and the label `font` (Press Start 2P), `font_size`, `line_color` and `line_width`. Sizes are given at `reference_tile` (141.5, a tile at 1920×1080), and each spot scales its font, shadow and the grid lines by its tile's size over that, so everything keeps its proportions at any window size. Green, outside and fallback are placeholder colours until they're designed.
- **Tiles follow the pockets.** `play.gd` passes `run.pockets` to `BettingView.show_pockets`, and each number tile takes the style of its pocket's colour. The red and black bets use the `outside` style like the other outside bets, for now, rather than their colour's. A run that recolours a pocket only has to call `show_pockets` again to recolour the table.
- **Grid lines** are a `line_color` border that `BetTable._draw` paints round each tile, under it. Neighbouring borders overlap exactly, so every line is the same width, and the empty corner under zero stays clear. A tile draws its own fill in `BetSpot._draw`, with its name centred on it in a Label using the style's colours and a hard drop shadow.
- **Rounded corners.** Tiles and their borders are drawn as `StyleBoxFlat`s (`TableStyle.box`), which take a radius per corner. Which corners round depends on where a tile sits, not what it is, so `BetTable` works it out from the grid: once the spots are added, `_find_outside_corners` marks a corner as outside when the three cells around it (beside, above or below, and diagonally) are all empty. Outside corners get `corner_radius` (at the reference tile, like the other sizes); zero is added with `zero_corners`, so its two left corners get `zero_corner_radius` of its width instead (0.5 gives quarter circles half zero's width; 1 makes its top and bottom one quarter circle each). Corners where tiles meet, such as zero against the dozens row, stay square, and new spots get the right corners without extra code. A border's radius is its tile's plus the line width, so the line stays even round the curve. `smooth_corners` off draws the curves without anti-aliasing, as hard steps that may suit the pixel art better.
- **Chips** (`scenes/chip/`) are `Chip`s (`chip.tscn`) in a row under the table, using Godot's Control drag and drop: `_get_drag_data` returns `{"chip": PlacedChip}` and shows another chip as the preview. Their values are `CHIP_VALUES` in `play.gd`, and a chip's **tier** is its index there, from 0 for the lowest. The values are a placeholder: chips don't cost money yet, and are planned to become fractions of the player's money, while the tiers stay put.
- **Chip art** comes from a `ChipSet` Resource, `scenes/chip/chip_set.tres`: one texture per tier, lowest first, picked by tier rather than value. It currently holds generated placeholder gradients (casino colours); replace each entry with the chip's texture. `chip.tscn` and `chip_stack.tscn` both point at it through their `chip_set` export.
- **Stacks**: each `BetSpot` draws its chips with a `ChipStack` (`chip_stack.tscn`), grouped into a column per tier (highest on the left), each chip `chip_rise` pixels above the one under it. Past `max_shown` chips a column stops growing and shows "×count". It ignores the mouse, so drops and right-clicks reach the spot.
- The table and chips are locked during a spin.

## Play views

A round has two screens: **betting** (`BettingView`: money, score and rolls remaining in `StatDisplay` boxes, the table, chips, tickets, consumables, and the WHEEL `SideTab` on the right edge) and **the wheel** (`WheelView`: the TABLE `SideTab` back to betting on the left edge, tickets, a live row per bet, the wheel and its round SPIN button). The SPIN button lives in the wheel's SubViewport in `play.tscn`, next to `RouletteWheel`, so the wheel shader bobs and shadows it with the wheel; `WheelView.set_wheel` sizes it over the hub (`RouletteWheel.hub_radius()`), and `WheelOutput` forwards the mouse into the viewport with `push_input`, since a SubViewport outside a SubViewportContainer gets no input. Clicks ignore the bob, so the clickable hub is where the wheel sits at rest. Players switch between them often, so:

- **Both live in the one play phase**, loaded for the whole round. Switching is UI, not a run step, so it doesn't go through the runner, and the wheel never has to be rebuilt.
- **They slide sideways** between each other, and a slide can be reversed mid-way. The tickets are one shared strip that glides between the views.
- **Views are display only.** They report input through signals and show what `play.gd` tells them; every rule stays in `play.gd`, so the views can be redesigned without touching game logic.
- **No going back to betting mid-spin.** The bets are locked anyway, and the spin plays out in the wheel view.

How the slide works is in [scene-flow.md](scene-flow.md#inside-the-play-phase).

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
| `modify_score(run, ctx)` | Change a winning bet's `ScoreContext` (called once per winning bet) |
| `modify_price(run, price) -> int` | Shop prices |
| `on_event(run, event, args)` | React to something that happened |

`Modifiers` (static) runs them in a fixed order: tickets in `run.tickets` order, then the current round's boss rules. **Game rules go through this loop; signals are only for UI, sound and animation**, because signal order is hidden and the trigger order is a gameplay mechanic.

Events, raised with `Modifiers.notify(run, event, args)`:

| Event | When | Args |
| --- | --- | --- |
| `pocket_passed` | The ball enters any pocket (dozens per spin, keep handlers cheap) | pocket, live `SpinContext` |
| `pocket_landed` | The ball settles | pocket |
| `spin_started` / `spin_finished` | Each spin | — / pocket |
| `round_started` / `round_finished` | Each round | round state / round state, won |
| `step_started` / `step_finished` | Every step | step / step, result |

`step_started` only fires when a step is first taken, not when a save resumes it.

**Tickets that count passes.** `PocketPassTicket` watches one pocket (`number`, optionally `colour`). It resets its count on `spin_started`, adds one for each matching `pocket_passed` that passes its `trigger_chance` roll (0 never, 1 always; rolled on `run.rng`, and not at all when 1) and calls `apply_pass(run, spin)`, which subclasses use (it gets the run and the live `SpinContext`) to change the spin's live mults as the ball goes over the pocket: `PassAddMultTicket` adds `amount` to every bet's mult, `PassMultiplyMultTicket` multiplies every bet's mult by `factor`. `PassAddMoneyTicket` instead adds `amount` to `run.money` (and the round's `money_earned`) on each pass, win or lose; the betting view's money label updates live. Passes therefore interleave with each other in the order they happen, and run before the other tickets' `modify_score`. `modify_score` only records the trace. The count is plain per-spin state, not saved, because saves are never made mid-spin. A lost bet still scores nothing, so its live mult is simply discarded.

### Scoring (placeholder)

A spin is scored in two layers:

- **`SpinContext`**: the whole spin. Created when the spin starts from the round's placed bets (so pass tickets can change mults live), and told the landed pocket afterwards via `land`. Holds one `ScoreContext` per bet, in the order they were placed, and totals them. Effects on the whole spin go through it: `add_mult` and `multiply_mult` change every bet.
- **`ScoreContext`**: one bet. It starts with `points` as the chips placed on the bet and `mult` as the bet's `base_mult`. If the bet won it passes through every modifier and totals `points × mult`; if it lost the total is 0 and no modifier runs.

`Modifiers.score` takes the bets in order and runs every modifier on each winning one, so a ticket's `modify_score` only ever deals with one bet. The spin's score is the sum of its bets'. The real formula (probably points × mult plus per-pocket bonuses) isn't designed yet; only `ScoreContext`, `SpinContext` and the play phase should change when it is.

**Live equations.** The wheel view has a `BetRow` per placed bet showing `name: chips × mult`. Before the spin it shows each bet's chips and `base_mult`. During the spin `play.gd` calls `WheelView.show_spin` on every `pocket_passed` with the live `SpinContext`, and each row pulses whenever its mult has changed, so pass tickets are seen bumping it. When the spin settles `show_result` sets each row to its final `chips × mult = total` (or "lost") and lists what each modifier did. The rows stay until the bets next change.

**Ticket pulse.** `Modifier` has a UI-only `triggered` signal. `PocketPassTicket` emits it on each matching pass, and the ticket's `Card` connects to it in `setup` and calls `pulse()`, a short scale pop layered on top of the hover scale. Other tickets don't emit it yet.

Modifiers record what they did in `ctx.trace`. Rules are computed instantly and the wheel view plays the trace back afterwards, so game logic never waits on animation.

## Cards and tooltips

`scenes/card/`, `scenes/card_container/`, `scenes/tooltip/`. Two layers:

- **The thing** is a `Modifier` Resource: a ticket now, consumables and the like later. It owns the data and behaviour, lives in `RunState` and is saved with it. It never knows how it's shown; it only emits `triggered` in case something is listening.
- **The card** (`Card`) is a view of one thing: its face. It draws the icon, tilts, bobs, pops on hover, pulses on `triggered` and shows the tooltip while hovered. It has no game logic and nothing worth saving, and can be thrown away and rebuilt from its item at any time.

The **tooltip** is a second view of the same thing, the detailed one. Neither view branches on what kind of thing it shows: they ask the item for `display_name`, `icon`, `get_description()` (may contain BBCode) and `get_kind_name()` ("Ticket"). Anything kind-specific a view needs, such as a different card frame later, should come from the item the same way, not from `if item is ...`.

**If it changes the run, it doesn't go in Card.** What interacting with a card means belongs to whatever holds it. `CardContainer` gives cards one interaction, drag to reorder, and reports it with `order_changed`; the play phase decides that means ticket trigger order and writes `run.tickets`. Clicking to buy will belong to the shop, clicking to use a consumable to wherever consumables are held. So every screen gets the same card and tooltip, and only adds what its interactions do.

Details:

- `CardContainer.set_items(items)` builds one card per item; `get_items()` returns them in on-screen order (assign it into a typed array such as `run.tickets`).
- The tooltip is one shared instance, the `Tooltip` autoload (a `CanvasLayer` on layer 5, above the HUD and below the pause menu). It isn't a child of the card so it isn't scaled with it, draws over every card, and only one shows at a time. Cards call `Tooltip.show_for(card)` and `Tooltip.hide_for(card)`; `hide_for` does nothing if another card has taken over, so a late `mouse_exited` can't hide the next card's tooltip.
- It anchors to `Card.get_resting_screen_rect()` (the card at `base_scale`) so it doesn't wobble with the hover pop, sits above the card (below if there's no room) and stays on screen. It reads the description each time it's shown, so changed values need no refresh. It hides while the game is paused.
- While a card is dragged it's `held`, which hides its tooltip. The other cards ignore the mouse during the drag, because Godot picks the hovered control by tree order, not `z_index`, so a neighbour would otherwise take the hover.

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
| Scoring | Per bet: chips × (bet's base mult plus modifiers); a lost bet scores 0; a spin scores the sum of its bets. Placeholder for now |
| Bets | `Bet` Resource; base mult = 36 / numbers covered; several bets per spin, used up by the spin |
| Play views | Betting and wheel views in one phase scene, sliding between each other; no going back to betting mid-spin |
| Triggers | All levels: pocket passed, landed, spin, round, step |
| Saving | Includes part-way through a round, saved after every spin |
| Ticket order | Matters; `run.tickets` order is the trigger order |

Still open:

- Linear queue or a branching map?
- Boss rules before or after tickets in the trigger order? (Currently after.)
- Should anything be able to change where the current ball lands? Today the winner is fixed at spin start.
- The scoring formula.
- Chips and money: should placing chips cost money, and should chip values be fractions of the player's money (the plan)? Today chips are free and fixed (`CHIP_VALUES`).
- What the shop sells besides tickets.

## Next

The real shop, boss rounds, skips and events, and more bet types.
