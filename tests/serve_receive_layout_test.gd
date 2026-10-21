extends SceneTree
# Each Serve Receive drill lies along its sector's short diagonal wall: the machine beside the middle of the wall, serving perpendicular to it.
const Layout := preload("res://scripts/map_layout.gd")
const Footprints := preload("res://scripts/drill_layout.gd")
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	var frames := {}
	for center in Layout.sectors():
		var frame: Dictionary = Layout.serve_receive_frame(center)
		frames[center] = frame
		var wall: Vector3 = frame.wall
		var normal: Vector3 = frame.normal
		var basis := Basis(Vector3.UP, float(frame.yaw))
		var machine_local := Layout.STATION_MACHINE_LOCAL
		check((Vector3(frame.origin) + basis * machine_local).distance_to(frame.machine) < 0.001, "The station's machine is where the frame says (sector %s)" % center)
		check(absf(Vector3(frame.machine).distance_to(wall) - Layout.SERVE_MACHINE_GAP) < 0.001, "The machine stands one metre off the middle of the wall")
		# Serves travel along the station's local +z, which must be the wall's normal (perpendicular to the wall and the pad)
		var serve_direction: Vector3 = basis * Vector3(0, 0, 1)
		check(serve_direction.distance_to(normal) < 0.001, "Serves leave perpendicular to the wall")
		var wall_direction := Vector3(cos(float(frame.wall_yaw)), 0.0, -sin(float(frame.wall_yaw)))
		check(absf(wall_direction.dot(normal)) < 0.001, "The wall direction and serve direction are at right angles")
		# the pad lies on the sector side of the wall
		var pad_center: Vector3 = Vector3(frame.origin) + basis * Vector3(16, 0, 4.5)
		check(normal.dot(pad_center - wall) > 9.0, "The pad lies beyond the wall, ten metres or more from it")
		# drinks keep their space
		for spot in Layout.drink_positions():
			var footprint: Rect2 = Footprints._receive_footprint(center)
			check(not footprint.has_point(Vector2(spot.x, spot.z)), "An Energy Drink is outside the pad area")
			check(Vector3(frame.machine).distance_to(spot) > 3.0, "An Energy Drink is clear of the machine")
	# 180-degree rotation between opposite sectors
	var a: Dictionary = frames[Vector2(-Layout.PIT_X, Layout.SECTOR_Z)]
	var b: Dictionary = frames[Vector2(Layout.PIT_X, -Layout.SECTOR_Z)]
	check(Vector3(a.machine).distance_to(-Vector3(b.machine)) < 0.001 and Vector3(a.normal).distance_to(-Vector3(b.normal)) < 0.001, "Opposite sectors are 180-degree rotations of each other")
	print("serve_receive_layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
