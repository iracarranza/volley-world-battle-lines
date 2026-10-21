extends "res://tests/support/test_case.gd"
# The map graybox: layout data, and that a body can really traverse it (and cannot go where the layout says it should not).
const Layout := preload("res://scripts/map_layout.gd")
var map: Node3D
var player: CharacterBody3D
func _initialize() -> void:
	call_deferred("run")
# Walk toward `target` (flat) for up to `seconds`, stopping within `reach` metres. Returns the distance left.
func walk_to(target: Vector3, seconds: float = 25.0, reach: float = 0.6, sprint: bool = true) -> float:
	var frames := int(seconds * 60.0)
	for i in range(frames):
		var flat := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
		if flat.length() <= reach:
			break
		player.tick(1.0 / 60.0, flat.normalized(), sprint)
		await physics_frame
	return Vector2(target.x - player.global_position.x, target.z - player.global_position.z).length()
func stand(position_in_world: Vector3) -> void:
	player.place(position_in_world)
	for i in range(12):
		player.tick(1.0 / 60.0, Vector3.ZERO, false)
		await physics_frame
func run() -> void:
	# --- Layout data ---
	var nets := Layout.nets()
	var by_id := {}
	for net in nets:
		by_id[net.id] = net
		check(is_zero_approx(net.position.z), "%s is on the central line" % net.id)
	check(nets.size() == 5, "three lane Nets and two Pit Nets")
	check(is_equal_approx(by_id.top.position.x, -by_id.bottom.position.x) and is_zero_approx(by_id.middle.position.x), "the lane Nets are symmetric about the middle")
	check(is_equal_approx(by_id.middle.position.x - by_id.top.position.x, 36.0*Layout.SPACING) and is_equal_approx(by_id.pit_east.position.x - by_id.middle.position.x, 18.0*Layout.SPACING), "Original net-center spacing expands by thirty percent")
	check(by_id.top.height > by_id.middle.height and by_id.middle.height > by_id.bottom.height, "the top Net is tallest and the bottom shortest")
	check(by_id.top.width < by_id.middle.width and by_id.middle.width < by_id.bottom.width, "the top court is narrowest and the bottom widest")
	check(is_equal_approx(by_id.pit_west.height, Layout.STANDARD_HEIGHT) and is_equal_approx(by_id.pit_east.width, Layout.STANDARD_WIDTH), "Pit Nets are the standard")
	check(absf(float(by_id.middle.height) - (float(by_id.top.height) + float(by_id.bottom.height)) * 0.5) < 0.02, "the middle Net sits at the middle of the lane values")
	check(Layout.zone_at(Vector3(0, 0, 58)*Layout.SPACING) == "BLUE BASE" and Layout.zone_at(Vector3(0, 0, -58)*Layout.SPACING) == "RED BASE", "base zones")
	check(Layout.zone_at(Vector3(0, 0, 30)*Layout.SPACING).begins_with("MIDDLE LANE") and Layout.zone_at(Vector3(-36, 0, 15)*Layout.SPACING).begins_with("TOP LANE"), "lane zones")
	check(Layout.zone_at(Vector3(-18, 0, 20)*Layout.SPACING).begins_with("UPPER JUNGLE") and Layout.zone_at(Vector3(18, 0, -20)*Layout.SPACING).begins_with("LOWER JUNGLE"), "jungle zones")
	check(Layout.zone_at(Vector3(-18, 0, 4)*Layout.SPACING) == "PIT" or Layout.zone_at(Vector3(-18, 0, 4)*Layout.SPACING).begins_with("PIT NET COURT"), "the pit")
	# --- Traversal in the real physics ---
	map = load("res://map_traversal.tscn").instantiate()
	root.add_child(map)
	player = map.player
	player.scripted = true
	for i in range(20):
		await physics_frame
	for team in ["blue", "red"]:
		for spawn in Layout.spawns(team):
			await stand(spawn)
			check(player.is_on_floor() and absf(player.global_position.y) < 0.2, "%s spawn %s is standing on the floor" % [team, str(spawn)])
	# Each lane can be walked from either base to the edge of its Net's court.
	for lane in Layout.lane_ids():
		for blue in [true, false]:
			var line := Layout.lane_points(lane)
			if not blue:
				line = Layout.mirrored(line)
			await stand(Vector3(line[0].x, 0.1, line[0].y))
			var left := 0.0
			for i in range(1, line.size()):
				left = await walk_to(Vector3(line[i].x, 0.0, line[i].y), 20.0, 1.0)
			check(left < 1.5, "%s lane walks from the %s base to its Net (%.1f m short)" % [lane, "Blue" if blue else "Red", left])
	# A Net is a wall across the central line, but the jungle between them is open.
	await stand(Vector3(-36.0*Layout.SPACING, 0.1, 6.0))
	await walk_to(Vector3(-36.0*Layout.SPACING, 0.0, -6.0), 8.0, 0.5)
	check(player.global_position.z > 0.0, "the top Net blocks walking across the central line (stopped at z %.2f)" % player.global_position.z)
	await stand(Vector3(-30.4*Layout.SPACING, 0.1, 14.0))
	var crossing := await walk_to(Vector3(-30.4*Layout.SPACING, 0.0, -14.0), 12.0, 0.6)
	check(crossing < 1.0, "the gap between the top Net and the west pit is open (%.1f m short)" % crossing)
	# The pit ring: closed from the side, open at the north and south ends.
	await stand(Vector3(-Layout.PIT_X-16, 0.1, 2.0))
	await walk_to(Vector3(-Layout.PIT_X, 0.0, 2.0), 8.0, 0.6)
	check(player.global_position.x < -Layout.PIT_X-8, "the pit wall stops you walking in from the side (x %.1f)" % player.global_position.x)
	await stand(Vector3(-Layout.PIT_X, 0.1, 16.0))
	var into := await walk_to(Vector3(-Layout.PIT_X, 0.0, 4.0), 8.0, 0.6)
	check(into < 1.0, "the pit opening lets you walk in from the north (%.1f m short)" % into)
	# Traversal clutter is gone: only floor, nets and retained walls have map colliders.
	for body in map.world.solids:
		check(body.get_meta("map_geometry","") in ["floor","net","wall"],"Map solid is floor, net or wall; no ramp/ledge/block remains")
	print("MAP TRAVERSAL CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
