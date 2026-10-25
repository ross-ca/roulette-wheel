class_name SpinContext
extends RefCounted
## One spin's score: a ScoreContext for each bet placed on it. Created when the spin starts, so
## pass tickets can change the bets' mults live, and told the landed pocket once the ball settles.
## Effects on the whole spin go through here; effects on one bet change that bet's ScoreContext.

var pocket: Pocket
## One per placed bet, in the order they were placed.
var bets: Array[ScoreContext] = []


func _init(placed: Array[PlacedBet]) -> void:
	for entry in placed:
		bets.append(ScoreContext.new(entry.total(), entry.bet))


func land(landed: Pocket) -> void:
	pocket = landed
	for ctx in bets:
		ctx.land(landed)


## Adds to every bet's mult.
func add_mult(amount: float) -> void:
	for ctx in bets:
		ctx.mult += amount


## Multiplies every bet's mult.
func multiply_mult(factor: float) -> void:
	for ctx in bets:
		ctx.mult *= factor


## The spin's score: the sum of its bets'. Lost bets add nothing.
func total() -> int:
	var sum := 0
	for ctx in bets:
		sum += ctx.total()
	return sum
