extends RefCounted

## Canonical player-attribute vocabulary. Gameplay formulas stay in their owning
## systems; this file exists so integration tooling has one auditable vocabulary.
const ABILITY_ATTRIBUTES = [
	"acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness",
	"stamina", "work_rate", "arm_speed", "serve_power", "serve_technique", "serve_placement",
	"serve_consistency", "serve_aggression", "serve_variation", "reception", "reception_balance",
	"reception_stability", "set_accuracy", "set_balance", "set_stability", "tempo_control",
	"set_disguise", "hand_control", "unpredictability", "attack_power", "attack_accuracy",
	"approach_timing", "tooling", "feinting", "finesse", "shot_variety", "block_timing",
	"ball_control", "dig_control", "court_vision", "anticipation", "decision_making", "composure",
	"tactical_discipline", "improvisation", "adaptability",
]

const PHYSICAL_ATTRIBUTES = [
	"acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness",
	"stamina", "arm_speed", "serve_power", "attack_power",
]

const MENTAL_ATTRIBUTES = [
	"court_vision", "anticipation", "decision_making", "composure", "tactical_discipline",
	"improvisation", "adaptability", "unpredictability", "work_rate",
]

## Profile data can reference these even though they are not trainable ability
## attributes. Leadership acts on teammates; ego is temperament.
const NON_ABILITY_TRAITS = ["leadership", "ego"]
