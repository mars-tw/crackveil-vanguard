extends RefCounted

const CHANCE := 0.18
const MULTIPLIER := 1.75

static func resolve(amount: float, seed_value: int, generation: int, hit_index: int) -> Dictionary:
	# Stable arithmetic, independent of encounter/loot and cosmetic RNG streams.
	var mixed := ((seed_value & 32767) * 2654435761 + generation * 1103515245 + hit_index * 12345) & 2147483647
	var critical := amount >= 8.0 and float(mixed % 10000) < CHANCE * 10000.0
	return {"critical": critical, "damage": amount * MULTIPLIER if critical else amount}
