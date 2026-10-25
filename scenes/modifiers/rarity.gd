class_name Rarity
extends RefCounted
## How rare a modifier is, and the cascading roll that picks one by rarity (for shop stock and the
## like). Each rarity has a roll chance, tried from the rarest down: a hit picks a random modifier
## of that rarity, a miss moves on to the next rarest. Common always hits. Because every rarity is
## rolled on its own, adding or removing modifiers of one rarity never dilutes the others.
##
## A rarity's real chance is its roll chance times the chance that every rarer one missed.

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

## Chance each rarity hits when it's rolled. Common must stay 1.0 so the cascade always ends.
const ROLL_CHANCE := {
	Tier.LEGENDARY: 0.02,
	Tier.EPIC: 0.08,
	Tier.RARE: 0.2,
	Tier.UNCOMMON: 0.4,
	Tier.COMMON: 1.0,
}

const NAMES := {
	Tier.COMMON: "Common",
	Tier.UNCOMMON: "Uncommon",
	Tier.RARE: "Rare",
	Tier.EPIC: "Epic",
	Tier.LEGENDARY: "Legendary",
}

const COLOURS := {
	Tier.COMMON: Color(0.75, 0.75, 0.75),
	Tier.UNCOMMON: Color(0.38, 0.8, 0.4),
	Tier.RARE: Color(0.35, 0.6, 1.0),
	Tier.EPIC: Color(0.7, 0.4, 0.95),
	Tier.LEGENDARY: Color(1.0, 0.65, 0.15),
}


## Picks one of `candidates` (modifiers) by the cascading roll, using `rng`. A rarity that hits but
## has no candidates counts as a miss. Returns null only if `candidates` is empty.
static func roll(rng: RandomNumberGenerator, candidates: Array) -> Modifier:
	if candidates.is_empty():
		return null
	for tier in [Tier.LEGENDARY, Tier.EPIC, Tier.RARE, Tier.UNCOMMON, Tier.COMMON]:
		if rng.randf() >= ROLL_CHANCE[tier]:
			continue
		var of_tier := candidates.filter(func(modifier: Modifier) -> bool: return modifier.rarity == tier)
		if not of_tier.is_empty():
			return of_tier[rng.randi_range(0, of_tier.size() - 1)]
	# Only reachable when there's nothing common to land on; any candidate beats none.
	return candidates[rng.randi_range(0, candidates.size() - 1)]
