extends RefCounted
## Resolved flight and evidence. Callers apply consequences after resolution.
var velocity := Vector3.ZERO
var assessment: Dictionary = {}
var influence: Dictionary = {}
var aiming: Dictionary = {}

var mechanics: Array = []
var outgoing_shot: Dictionary = {}
var separation_offset := Vector3.ZERO
