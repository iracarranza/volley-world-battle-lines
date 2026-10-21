extends RefCounted
## Ground envelopes include the playable pad and its targets/feed machinery.
const SPIKE_REFERENCE := Vector3(-16,0,1.5)
const BOX_REFERENCE := Vector3(-36,0,4)
const SPIKE_PAD := Rect2(-19,-9.7,6,13.7)
const BOX_PAD := Rect2(-44,-9,20,28)
const RECEIVE_ENVELOPE := Rect2(-3,-15.25,6,19.75)
const TRANSITION_ENVELOPE := Rect2(-7.5,-10,15,14)

static func footprint(marker: Dictionary) -> Rect2:
	var center := Vector2(marker.position.x,marker.position.z)
	match marker.type:
		"spike": return Rect2(center+SPIKE_PAD.position-Vector2(SPIKE_REFERENCE.x,SPIKE_REFERENCE.z),SPIKE_PAD.size)
		"box": return Rect2(center+BOX_PAD.position-Vector2(BOX_REFERENCE.x,BOX_REFERENCE.z),BOX_PAD.size)
		"receive": return Rect2(center+RECEIVE_ENVELOPE.position,RECEIVE_ENVELOPE.size)
		_: return Rect2(center+TRANSITION_ENVELOPE.position,TRANSITION_ENVELOPE.size)
