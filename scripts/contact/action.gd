extends RefCounted
## Stable action values shared by controls, rules and serialized contact events.
enum Type { RECEIVE, SET, ATTACK, BLOCK, SERVE }
const LABELS := ["RECEIVE", "SET", "ATTACK", "BLOCK", "SERVE"]
const SHOT_KINDS := ["receive", "set", "attack", "block", "serve"]
