extends RefCounted

# The graybox map as data, separate from the Contact Lab. Axes: the central line runs along x at z = 0, Blue is z > 0 and Red
# is z < 0, west is the top lane and east is the bottom lane. Nothing here is a decided number except the topology (see
# docs/map-spec.md); heights, widths and distances are the placeholders in docs/map-build-plan.md.
const SPACING := 1.30
const HALF := 80.0 * SPACING
const LANE_WIDTH := 5.0
const BASE_Z := 58.0 * SPACING
const BASE_SIZE := Vector2(14.0, 8.0)
const STANDARD_HEIGHT := 2.43
const STANDARD_WIDTH := 9.0
const STANDARD_DEPTH := 18.0
const PIT_X := 18.0 * SPACING
const PIT_RING_RADIUS := 10.5
const SECTOR_Z := 22.0 * SPACING

# The three lane Nets: height, and the scale applied to the standard court width and depth.
const LANE_NETS := {
	"top": {"x": -36.0, "height": 2.60, "scale": 0.8, "label": "TOP NET"},
	"middle": {"x": 0.0, "height": 2.42, "scale": 1.0, "label": "MIDDLE NET"},
	"bottom": {"x": 36.0, "height": 2.24, "scale": 1.2, "label": "BOTTOM NET"},
}

# Every Net on the central line: the three lane Nets and the two Pit Nets.
static func nets() -> Array:
	var out := []
	for id in LANE_NETS:
		var kind: Dictionary = LANE_NETS[id]
		out.append({
			"id": id, "kind": "lane", "label": kind.label,
			"position": Vector3(float(kind.x) * SPACING, 0.0, 0.0), "height": float(kind.height),
			"width": STANDARD_WIDTH * float(kind.scale), "depth": STANDARD_DEPTH * float(kind.scale),
		})
	for side in [-1.0, 1.0]:
		out.append({
			"id": "pit_west" if side < 0.0 else "pit_east", "kind": "pit", "label": "PIT NET",
			"position": Vector3(side * PIT_X, 0.0, 0.0), "height": STANDARD_HEIGHT,
			"width": STANDARD_WIDTH, "depth": STANDARD_DEPTH,
		})
	return out

static func net_by_id(id: String) -> Dictionary:
	for net in nets():
		if net.id == id:
			return net
	return {}

# A lane's centre line for Blue (z > 0), from the base to the edge of its Net's court. Red is the mirror (see mirrored).
static func lane_points(lane: String) -> Array[Vector2]:
	var net := net_by_id(lane)
	var end_z: float = float(net.depth) * 0.5 + 0.3
	var x: float = net.position.x
	var points: Array[Vector2] = []
	if lane == "middle":
		points.append(Vector2(0.0, BASE_Z - 2.0))
		points.append(Vector2(0.0, end_z))
	else:
		var sign_x := -1.0 if lane == "top" else 1.0
		points.append(Vector2(sign_x * 6.0, BASE_Z - 2.0))
		points.append(Vector2(x, 24.0 * SPACING))
		points.append(Vector2(x, end_z))
	return points

static func mirrored(points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in points:
		out.append(Vector2(p.x, -p.y))
	return out

static func lane_ids() -> Array:
	return ["top", "middle", "bottom"]

# Five spawn points on each base.
static func spawns(team: String) -> Array[Vector3]:
	var z := BASE_Z if team == "blue" else -BASE_Z
	var out: Array[Vector3] = []
	for i in range(5):
		out.append(Vector3(-6.0 + 3.0 * i, 0.1, z))
	return out

# Jungle sector centres: the Serve Receive Drill sits in the middle of each.
static func sectors() -> Array[Vector2]:
	return [Vector2(-PIT_X, SECTOR_Z), Vector2(PIT_X, SECTOR_Z), Vector2(-PIT_X, -SECTOR_Z), Vector2(PIT_X, -SECTOR_Z)]

# A point in a sector's own frame: +x runs toward the middle lane, +z away from the central line.
static func sector_point(center: Vector2, local_x: float, local_z: float) -> Vector3:
	var mx := -signf(center.x)
	var mz := signf(center.y)
	return Vector3(center.x + mx * local_x * SPACING, 0.0, center.y + mz * local_z * SPACING)

static func sector_step(center: Vector2,index: int) -> Vector3:
	# A stair is one obstacle assembly: move its center, preserve its local step spacing.
	return sector_point(center,-5.8,4.0)+Vector3(-signf(center.x)*3.2*(index-1),0,0)

static func distance_to_polyline(point: Vector2, points: Array[Vector2]) -> float:
	var best := INF
	for i in range(points.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
		best = minf(best, point.distance_to(closest))
	return best

# What part of the map a point is in, for the HUD and the tests.
static func zone_at(position: Vector3) -> String:
	var p := Vector2(position.x, position.z)
	var half := "BLUE" if p.y >= 0.0 else "RED"
	if absf(p.y) >= BASE_Z - BASE_SIZE.y * 0.5 and absf(p.x) <= BASE_SIZE.x * 0.5:
		return "%s BASE" % half
	for net in nets():
		var local := p - Vector2(net.position.x, net.position.z)
		if absf(local.x) <= float(net.width) * 0.5 and absf(local.y) <= float(net.depth) * 0.5:
			return "%s COURT (%s)" % [String(net.label), half] if net.kind == "lane" else "PIT NET COURT (%s)" % half
	for side in [-1.0, 1.0]:
		if p.distance_to(Vector2(side * PIT_X, 0.0)) <= PIT_RING_RADIUS + 0.5:
			return "PIT"
	for lane in lane_ids():
		var line := lane_points(lane)
		if distance_to_polyline(p, line if p.y >= 0.0 else mirrored(line)) <= LANE_WIDTH * 0.5:
			return "%s LANE (%s)" % [lane.to_upper(), half]
	if absf(p.x) <= 36.0 * SPACING + LANE_WIDTH * 0.5:
		return "%s JUNGLE (%s)" % ["UPPER" if p.x < 0.0 else "LOWER", half]
	return "OUTER FLOOR"

# Shared activity anchors: rendering and gameplay always use these same positions.
static func drill_markers() -> Array:
	var result := []
	for side in [1.0,-1.0]:
		var half := "blue" if side > 0 else "red"
		result.append({"id":"box_jump_"+half,"type":"box","position":Vector3(-46,0,side*22)*SPACING})
		result.append({"id":"transition_set_"+half,"type":"transition","position":Vector3(46,0,side*22)*SPACING})
	var centers := sectors()
	for i in range(centers.size()):
		result.append({"id":"receive_%d"%i,"type":"receive","position":Vector3(centers[i].x,0,centers[i].y)})
		result.append({"id":"spike_%d"%i,"type":"spike","position":sector_point(centers[i],3,-9)})
	return result

static func drill_marker(id: String) -> Dictionary:
	for marker in drill_markers():
		if marker.id == id: return marker
	return {}

static func drink_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x in [-1.0,1.0]:
		for z in [-1.0,1.0]:
			result.append(Vector3(x*PIT_X,0,z*13.8*SPACING))
			result.append(Vector3(x*8,0,z*52)*SPACING)
	return result
