class_name CardBalance
extends RefCounted

# One source of truth for setup previews, combat, and the balance report.
# Keep low-ranked preferences relevant while leaving room for liked dishes to heal.
const DAMAGE = [30, 28, 26, 24, 22, 20, 18]
const HEAL = [16, 14, 12, 10, 8, 6, 4]
const EFFECTS = [2, 2, 1, 1, 0, 0, 0]
const MAX_HIT = 60

static func hp(category: String, rank: int) -> int:
	var index = clampi(rank, 1, 7) - 1
	return DAMAGE[index] if category == "disliked" else (HEAL[index] if category == "liked" else 0)

static func effects(category: String, rank: int) -> int:
	return 1 if category == "neutral" else EFFECTS[clampi(rank, 1, 7) - 1]

static func summary(category: String, rank: int) -> String:
	var power = "%d damage" % hp(category, rank) if category == "disliked" else "%d healing" % hp(category, rank)
	if category == "neutral":
		power = "No HP change"
	return "%s · %d effects" % [power, effects(category, rank)]
