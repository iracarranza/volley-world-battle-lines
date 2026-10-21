extends SceneTree
# The Pits' short walls: the west (top-lane) Pit is narrowed on Blue's side (open to Red), the east (bottom-lane) Pit on Red's side, and the two are
# 180-degree rotations of each other.
const Layout := preload("res://scripts/map_layout.gd")
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	var west: Dictionary = Layout.pit_short_wall(-1.0)
	var east: Dictionary = Layout.pit_short_wall(1.0)
	check(Vector3(west.center).z > 0.0 and Vector3(east.center).z < 0.0, "The west Pit's wall is on Blue's side, the east Pit's on Red's")
	check(Vector3(west.center).distance_to(-Vector3(east.center)) < 0.001 and is_equal_approx(float(west.length), float(east.length)), "They are 180-degree rotations of each other")
	var pit_x := Layout.PIT_X
	check(absf(Vector3(west.center).x + pit_x) < 3.0 and absf(Vector3(east.center).x - pit_x) < 3.0, "Each sits across its own Pit's opening")
	check(float(west.length) < 8.5, "It narrows the opening without closing it")
	# built into the world
	var lab = load("res://map_graybox.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var found := 0
	for body in lab.map_world.solids:
		if body.get_meta("map_geometry", "") != "wall":
			continue
		for wall in [west, east]:
			if Vector3(body.position).distance_to(Vector3(wall.center) + Vector3(0, 1.2, 0)) < 0.01:
				found += 1
	check(found == 2, "Both short walls are built (%d)" % found)
	print("pit_access: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
