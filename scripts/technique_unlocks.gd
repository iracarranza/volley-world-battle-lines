extends RefCounted
## MS-14 technique-unlock table (T-TR): which trait id unlocks which technique and which code owns the reader. Today's four, unchanged.
## `kind` "taken" = the athlete took the trait at all (a successor consuming it keeps the unlock); "active" = `has_trait` (still on the frontier).
const TABLE := {
	"back_set": {"trait": "accuracy_back_set", "owner": "contact_lab.gd", "kind": "taken"},
	"float_serve": {"trait": "acc_float_serve", "owner": "contact_lab.gd", "kind": "taken"},
	"rolling_receive": {"trait": "endurance_rolling_receive", "owner": "contact_lab.gd", "kind": "active"},
	"quick_step": {"trait": "speed_quick_step", "owner": "lab/athlete_motor.gd", "kind": "active"},
}

static func trait_for(technique: String) -> String:
	return String(TABLE[technique].trait)
