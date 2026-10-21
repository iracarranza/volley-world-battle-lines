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
	"top": {"x": -64.0 / SPACING, "height": 2.60, "scale": 0.8, "label": "TOP NET"},
	"middle": {"x": 0.0, "height": 2.42, "scale": 1.0, "label": "MIDDLE NET"},
	"bottom": {"x": 64.0 / SPACING, "height": 2.24, "scale": 1.2, "label": "BOTTOM NET"},
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
# Pit access: each Pit ring has two openings, north (Red's side) and south (Blue's side). The short wall narrows one of them, and the two Pits
# are 180-degree rotations of each other: the top-lane (west) Pit is narrowed toward Blue (open to Red), the bottom-lane (east) Pit toward Red
# (more access to Blue). It spans 5.5 m of the roughly 8.5 m opening and leaves the gap toward the central line.
const PIT_SHORT_WALL_LENGTH := 5.5
const PIT_SHORT_WALL_SHIFT := 1.5
static func pit_short_wall(side: float) -> Dictionary:
	return {"center": Vector3(side * PIT_X + side * PIT_SHORT_WALL_SHIFT, 0.0, -side * PIT_RING_RADIUS), "length": PIT_SHORT_WALL_LENGTH}

static func sectors() -> Array[Vector2]:
	return [Vector2(-PIT_X, SECTOR_Z), Vector2(PIT_X, SECTOR_Z), Vector2(-PIT_X, -SECTOR_Z), Vector2(PIT_X, -SECTOR_Z)]

# A point in a sector's own frame: +x runs toward the middle lane, +z away from the central line.
static func sector_point(center: Vector2, local_x: float, local_z: float) -> Vector3:
	var mx := -signf(center.x)
	var mz := signf(center.y)
	return Vector3(center.x + mx * local_x * SPACING, 0.0, center.y + mz * local_z * SPACING)

# The Serve Receive drill of a sector is laid out from the short diagonal wall beside it: the pad is parallel to the wall, and the serving
# machine stands beside the middle of the wall (one metre off it), sending its serves perpendicular to the wall and the pad.
# Returns the wall's centre and yaw, the machine's world position, the station's own origin (its local (0,0) pad corner) and yaw, and the
# unit normal from the wall toward the pad.
const SERVE_WALL_YAW_DEGREES := 15.0
const SERVE_MACHINE_GAP := 1.0
const STATION_MACHINE_LOCAL := Vector3(16.0, 0.0, -10.0) # the machine's place in the station's own frame
static func serve_receive_frame(center: Vector2) -> Dictionary:
	var mx := -signf(center.x)
	var mz := signf(center.y)
	var wall := sector_point(center, 6.0, -6.0)
	var wall_yaw := deg_to_rad(SERVE_WALL_YAW_DEGREES) * mx * mz * -1.0
	var normal := Vector3(sin(wall_yaw), 0.0, cos(wall_yaw))
	var yaw := wall_yaw
	if normal.dot(Vector3(center.x - wall.x, 0.0, center.y - wall.z)) < 0.0:
		normal = -normal
		yaw += PI
	var machine := wall + normal * SERVE_MACHINE_GAP
	var origin := machine - Basis(Vector3.UP, yaw) * STATION_MACHINE_LOCAL
	return {"wall": wall, "wall_yaw": wall_yaw, "machine": machine, "origin": origin, "yaw": yaw, "normal": normal}

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
	if absf(p.x) <= absf(float(net_by_id("bottom").position.x)) + LANE_WIDTH * 0.5:
		return "%s JUNGLE (%s)" % ["UPPER" if p.x < 0.0 else "LOWER", half]
	return "OUTER FLOOR"

# Shared activity anchors: rendering and gameplay always use these same positions.
# Box Jump and Transition Set sit on the outer side of the side lanes (Box Jump outside the top lane, Transition Set outside the bottom lane);
# the four Spike Trainers lie horizontally in the open ground between the side courts and the Pits, hitting outward toward the lane.
const BOX_OUTSIDE_LANE := 10.0        # metres from the lane centre to the Box Jump tower
const TRANSITION_OUTSIDE_LANE := 12.0 # metres from the lane centre to the Transition Set pad
const SPIKE_X := 46.0                 # metres from the central line
const SPIKE_Z := 22.0 * SPACING
static func drill_markers() -> Array:
	var result := []
	var top_x: float = float(net_by_id("top").position.x)
	var bottom_x: float = float(net_by_id("bottom").position.x)
	for side in [1.0,-1.0]:
		var half := "blue" if side > 0 else "red"
		result.append({"id":"box_jump_"+half,"type":"box","position":Vector3(top_x-BOX_OUTSIDE_LANE,0,side*22*SPACING)})
		result.append({"id":"transition_set_"+half,"type":"transition","position":Vector3(bottom_x+TRANSITION_OUTSIDE_LANE,0,side*22*SPACING)})
	var centers := sectors()
	for i in range(centers.size()):
		# A receive marker is its pad's centre (the station is laid out from the sector's diagonal wall); the sector centre is kept as "sector".
		var frame := serve_receive_frame(centers[i])
		result.append({"id":"receive_%d"%i,"type":"receive","position":Vector3(frame.origin)+Basis(Vector3.UP,float(frame.yaw))*Vector3(16,0,4.5),"sector":centers[i]})
		var side_x := signf(centers[i].x)
		# Hits go toward the lane: local -z becomes +x (east) or -x (west).
		result.append({"id":"spike_%d"%i,"type":"spike","position":Vector3(side_x*SPIKE_X,0,signf(centers[i].y)*SPIKE_Z),"yaw":-side_x*PI*0.5})
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
	result.append_array(outer_drink_positions())
	result.append_array(top_vertex_drink_positions())
	return result

# Drinks for the top laners at the vertex where the diagonal meets the straight run to the Net, inside the Box Jump area. Mirrored across the
# central line like the lane itself, so each team's top laner has one.
const VERTEX_DRINK_INSET := 2.0 # metres from the Box Jump tower's centre line, toward the lane
static func top_vertex_drink_positions() -> Array[Vector3]:
	var vertex: Vector2 = lane_points("top")[1]
	var tower_x: float = float(net_by_id("top").position.x) - BOX_OUTSIDE_LANE
	var result: Array[Vector3] = []
	for sign_z in [1.0, -1.0]:
		result.append(Vector3(tower_x + VERTEX_DRINK_INSET, 0.0, sign_z * vertex.y))
	return result

# A slightly unsafe pair of drinks beyond the bottom lane Net, between the two Transition Set spots. It is mirrored across the central line
# (not rotated to the top lane), so both teams' bottom-lane pairs can reach one, and it follows the bottom Net if that Net moves.
const OUTER_DRINK_GAP := 10.0 # metres past the Net's end
const OUTER_DRINK_Z := 8.0    # metres either side of the central line
static func outer_drink_positions() -> Array[Vector3]:
	var net := net_by_id("bottom")
	var x: float = float(net.position.x) + float(net.width) * 0.5 + OUTER_DRINK_GAP
	var result: Array[Vector3] = []
	for z in [-OUTER_DRINK_Z, OUTER_DRINK_Z]:
		result.append(Vector3(x,0,z))
	return result

static func overlaps_drill(bounds: Rect2,clearance: float = 0.0) -> bool:
	for marker in drill_markers():
		if preload("res://scripts/drill_layout.gd").footprint(marker).grow(clearance).intersects(bounds): return true
	return false
