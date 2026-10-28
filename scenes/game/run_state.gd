class_name RunState
extends Resource
## Everything about a run that outlives a single phase. Held by the Game autoload as `Game.run` and
## saved whole with ResourceSaver, so anything that must survive a save is an exported property.
##
## Effects never overwrite base values here: effective values are computed through `Modifiers` each
## time, so selling or reordering a ticket can't leave the run in a corrupted state.

@export var rng_seed: int = 0
## Copied from `rng.state` when saving, and restored on load.
@export var rng_state: int = 0
## The table being played, from 1. 0 before the first table starts.
@export var table: int = 0
@export var money: int = 0
## Trigger order is array order, left to right.
@export var tickets: Array[Ticket] = []
## One-use items the player is holding, used in the play phase.
@export var consumables: Array[Consumable] = []
## The wheel, clockwise from the top.
@export var pockets: Array[Pocket] = []
## Upcoming steps; index 0 is next.
@export var steps: Array[RunStep] = []
## The step being played. Set while a step is in progress, so a loaded save resumes it.
@export var current_step: RunStep
## Progress through the current round. Set while a round is in progress.
@export var current_round: RoundState
@export var base_spins_per_round: int = 4
@export var is_over: bool = false

## All of the run's randomness goes through this, so runs are reproducible from their seed.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
