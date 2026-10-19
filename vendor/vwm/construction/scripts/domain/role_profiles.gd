class_name RoleProfiles
extends RefCounted

## Canonical role profile data shared by player scoring and generation. Situation
## capability remains in capability systems rather than becoming a role permission.

const POSITION_WEIGHTS := {
	"Setter": ["set_accuracy", "set_balance", "set_stability", "tempo_control", "set_disguise", "hand_control", "unpredictability", "court_vision", "decision_making"],
	"Outside Hitter": ["attack_power", "attack_accuracy", "approach_timing", "tooling", "finesse", "shot_variety", "reception", "reception_balance", "work_rate"],
	"Middle Blocker": ["block_timing", "jump_reach", "explosiveness", "lateral_speed", "attack_power", "approach_timing", "anticipation", "work_rate"],
	"Opposite": ["attack_power", "attack_accuracy", "jump_reach", "approach_timing", "tooling", "shot_variety", "block_timing", "serve_power"],
	"Libero": ["reception", "reception_balance", "reception_stability", "dig_control", "ball_control", "anticipation", "lateral_speed", "decision_making", "work_rate"],
}

const POSITION_APPROACH_STEP_MODIFIER := {
	"Middle Blocker": 0.68,
	"Setter": 0.75,
	"Outside Hitter": 1.0,
	"Opposite": 1.0,
	"Libero": 1.0,
}

const POSITION_APPROACH_TOLERANCE_MODIFIER := {
	"Middle Blocker": 0.80,
	"Setter": 0.85,
}

const POSITIONS: Array[Dictionary] = [
	{"role": "Setter", "code": "S"},
	{"role": "Outside Hitter", "code": "OH1"},
	{"role": "Outside Hitter", "code": "OH2"},
	{"role": "Middle Blocker", "code": "M1"},
	{"role": "Middle Blocker", "code": "M2"},
	{"role": "Opposite", "code": "OP"},
	{"role": "Libero", "code": "L"},
	{"role": "Setter", "code": "S2"},
	{"role": "Outside Hitter", "code": "OH3"},
	{"role": "Middle Blocker", "code": "M3"},
]

const ROLE_SECONDARY := {
	"Setter": ["composure", "adaptability", "tactical_discipline", "anticipation",
			"serve_technique", "serve_consistency", "serve_placement", "ball_control"],
	"Outside Hitter": ["feinting", "court_vision", "composure", "serve_technique",
			"serve_consistency", "explosiveness", "jump_reach", "block_timing",
			"lateral_speed", "reception_stability"],
	"Middle Blocker": ["attack_accuracy", "tooling", "feinting", "shot_variety",
			"ball_control", "serve_technique", "stamina", "transition_speed", "arm_speed"],
	"Opposite": ["feinting", "finesse", "serve_technique", "serve_aggression",
			"serve_variation", "explosiveness", "arm_speed", "work_rate"],
	"Libero": ["court_vision", "adaptability", "composure", "transition_speed",
			"stamina", "tactical_discipline", "acceleration"],
}

const ROLE_HEIGHT_SPREAD := {
	"Setter": 7.0,
	"Outside Hitter": 7.5,
	"Middle Blocker": 8.0,
	"Opposite": 7.5,
	"Libero": 6.0,
}

const POSITION_EGO_BIAS := {
	"Opposite": 9.0, "Outside Hitter": 5.0, "Middle Blocker": 0.0,
	"Setter": -4.0, "Libero": -8.0,
}

const POSITION_LEADERSHIP_BIAS := {
	"Setter": 8.0, "Libero": 5.0, "Middle Blocker": 0.0,
	"Outside Hitter": -1.0, "Opposite": -3.0,
}

const POSITION_AGGRESSION_BIAS := {
	"Opposite": 12.0, "Outside Hitter": 6.0, "Middle Blocker": 2.0,
	"Setter": -7.0, "Libero": -13.0,
}

static func primary_attributes(role_name: String) -> Array:
	return Array(POSITION_WEIGHTS.get(role_name, []))

static func secondary_attributes(role_name: String) -> Array:
	return Array(ROLE_SECONDARY.get(role_name, []))
