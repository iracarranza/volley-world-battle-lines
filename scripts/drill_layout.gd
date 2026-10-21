extends RefCounted
## Ground envelopes include the playable pad and its targets/feed machinery.
const SPIKE_REFERENCE := Vector3(-16,0,1.5)
const BOX_REFERENCE := Vector3(-36,0,4)
const SPIKE_PAD := Rect2(-19,-9.7,6,13.7)
# The tower stands at the reference (-36, 4); the pad is its approach run and decks only (7 m wide, from just behind the tower to the start).
const BOX_PAD := Rect2(-39.5,0.5,7,15.5)
const RECEIVE_ENVELOPE := Rect2(-3,-15.25,6,19.75)
const TRANSITION_ENVELOPE := Rect2(-7.5,-10,15,14)

static func footprint(marker: Dictionary) -> Rect2:
	var center := Vector2(marker.position.x,marker.position.z)
	match marker.type:
		"spike": return _spike_footprint(center, float(marker.get("yaw", 0.0)))
		"box": return Rect2(center+BOX_PAD.position-Vector2(BOX_REFERENCE.x,BOX_REFERENCE.z),BOX_PAD.size)
		"receive": return _receive_footprint(marker.sector)
		_: return Rect2(center+TRANSITION_ENVELOPE.position,TRANSITION_ENVELOPE.size)

# The pad (6 x 9 m, in the station's own frame) laid out along its diagonal wall: the bounding rectangle of its corners, with a margin.
static func _receive_footprint(center: Vector2) -> Rect2:
	var Layout := preload("res://scripts/map_layout.gd")
	var frame: Dictionary = Layout.serve_receive_frame(center)
	var basis := Basis(Vector3.UP, float(frame.yaw))
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [Vector3(13, 0, 0), Vector3(19, 0, 0), Vector3(13, 0, 9), Vector3(19, 0, 9)]:
		var world: Vector3 = Vector3(frame.origin) + basis * corner
		low = Vector2(minf(low.x, world.x), minf(low.y, world.z))
		high = Vector2(maxf(high.x, world.x), maxf(high.y, world.z))
	return Rect2(low, high - low).grow(1.0)

# The Spike Trainer pad, turned about its marker by the marker's yaw: the bounding rectangle of its corners.
static func _spike_footprint(center: Vector2, yaw: float) -> Rect2:
	var basis := Basis(Vector3.UP, yaw)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var local := Vector3(SPIKE_PAD.position.x + corner.x * SPIKE_PAD.size.x - SPIKE_REFERENCE.x, 0.0, SPIKE_PAD.position.y + corner.y * SPIKE_PAD.size.y - SPIKE_REFERENCE.z)
		var rotated: Vector3 = basis * local
		low = Vector2(minf(low.x, center.x + rotated.x), minf(low.y, center.y + rotated.z))
		high = Vector2(maxf(high.x, center.x + rotated.x), maxf(high.y, center.y + rotated.z))
	return Rect2(low, high - low)
