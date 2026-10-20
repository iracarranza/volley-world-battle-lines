extends Node3D

const CENTER := Vector3(16, 0, 6.5)
const SERVE_BASELINE_Z := -10.0
const SERVE_CONTACT_HEIGHT := 3.60
const CHARGES := [0.45, 0.55, 0.65, 0.60, 0.70, 0.75]
const WIDTH := 6.0
# The near end lines up with the Net and the far end with the home court's endline (a full 9 m half court).
const LENGTH := 9.0
const HALF := LENGTH * 0.5
const GOAL := 8
# The +2 area is one quadrant of the scoring half: half the width of the scoring half and half its length, far from the receiver and on the right.
const TWO_LENGTH := HALF * 0.5
# A receive must be this high when it crosses into the scoring half (the red barrier along the half line) or it scores nothing. Provisional.
const CLEARANCE_HEIGHT := 3.4
const TOSS_SECONDS := 0.60
const TOSS_HEIGHT := 1.80
var toss_elapsed := 0.0
var feed_index := 0
# The feed order is a shuffled bag: every spot is served once, in random order, before any comes round again, and the first of a new bag is
# never the last of the old one.
var feed_bag: Array = []
var rng := RandomNumberGenerator.new()
var force_next_feed := -1
var feed_follow := 0.0
var striker: MeshInstance3D
var feeder_label: Label3D
const START := Vector3(13.5, 0, 7.4)
# Landing spots for the feeds, all in the receiving half and well back from the scoring half (z 0 to 4.5), so a receive has room to rise.
const TARGETS := [Vector3(14, 0.105, 7.2), Vector3(18, 0.105, 7.6), Vector3(15, 0.105, 8.5), Vector3(17.5, 0.105, 7.0), Vector3(13.8, 0.105, 7.9), Vector3(18.2, 0.105, 8.7)]
enum State { IDLE, WAITING, SERVING, RETURNING, COMPLETE, FAILED, TOSS }
var state := State.IDLE
var lab: Node3D
var streak := 0 # Successful scoring receives, retained for debug compatibility.
var points := 0
var serves_sent := 0
var last_points := 0
var last_landing := Vector3.ZERO
var timer := 0.0
var serve_duration := 0.0
var earned_xp := 0
var detail := "Walk east to the Serve Receive station."
var zone_was_entered := false
var marker: MeshInstance3D
var barrier: Node3D
var crossed := false
var cleared := true
var cross_height := 0.0
var previous_ball := Vector3.INF
# Where the whole station sits in the world. Zero in the Contact Lab; a hosting scene moves it (LabHost: lab.station_origin).
var origin := Vector3.ZERO

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	origin = lab.station_origin
	position = origin
	lab.world_builder.box(self, Vector3(WIDTH, 0.12, LENGTH), Vector3(16, -0.06, HALF), Color("304d69"))
	for x in [13.0, 19.0]:
		lab.world_builder.box(self, Vector3(0.06, 0.025, LENGTH), Vector3(x, 0.025, HALF), Color("91b8f2"))
	for z in [0.0, HALF, LENGTH]:
		lab.world_builder.box(self, Vector3(WIDTH, 0.025, 0.06), Vector3(16, 0.025, z), Color("91b8f2"))
	lab.world_builder.box(self, Vector3(WIDTH, 0.015, HALF), Vector3(16, 0.012, HALF * 0.5), Color("386b70"))
	lab.world_builder.box(self, Vector3(WIDTH * 0.5, 0.018, TWO_LENGTH), Vector3(17.5, 0.023, TWO_LENGTH * 0.5), Color("78703c"))
	lab.world_builder.box(self, Vector3(0.04, 0.025, HALF), Vector3(16.0, 0.04, HALF * 0.5), Color("b7d6bd"))
	lab.world_builder.box(self, Vector3(WIDTH * 0.5, 0.025, 0.04), Vector3(17.5, 0.04, TWO_LENGTH), Color("b7d6bd"))
	_build_barrier()
	lab.world_builder.world_label("RECEIVE HERE / 1 PT", Vector3(14.5, 0.15, HALF * 0.5) + origin, 24, Color("9ce5d8"))
	lab.world_builder.world_label("2 PTS", Vector3(17.5, 0.15, TWO_LENGTH * 0.5) + origin, 28, Color("ffe28a"))
	# A continuous traversable connection, no teleport or scene change.
	for x in range(5, 13):
		lab.world_builder.box(self, Vector3(0.6, 0.025, 0.14), Vector3(x, 0.025, 6), Color("8bbdf4"))
	lab.world_builder.world_label("SERVE RECEIVE  /  8 POINTS", Vector3(16, 0.4, -0.4) + origin, 42, Color("8bbdf4"))
	lab.world_builder.world_label("SERVE RECEIVE  →", Vector3(6.5, 0.2, 5) + origin, 30, Color("8bbdf4"))
	lab.world_builder.world_label("I / START OR RETRY", START + Vector3(0, 0.2, 1.5) + origin, 27, Color("cbdfff"))
	marker = lab.world_builder.ring(1.25, Color("8bbdf4"))
	marker.position = START + Vector3.UP * 0.04 + origin
	for target in TARGETS:
		var target_ring: MeshInstance3D = lab.world_builder.ring(0.38, Color("547da4"))
		target_ring.position = Vector3(target.x, 0.025, target.z) + origin
	var machine: MeshInstance3D = lab.world_builder.box(self, Vector3(1.0, 1.3, 1), Vector3(16, 0.65, SERVE_BASELINE_Z), Color("607f9e"))
	lab.world_builder.box(self, Vector3(0.15, 3.6, 0.15), Vector3(15.35, 2.45, SERVE_BASELINE_Z), Color("607f9e"))
	striker = lab.world_builder.box(self, Vector3(0.65, 0.18, 0.55), Vector3(16, 4.5, SERVE_BASELINE_Z), Color("ffb46e"))
	feeder_label = Label3D.new()
	add_child(feeder_label)
	feeder_label.position = machine.position + Vector3.UP * 4.7
	feeder_label.text = "JUMP SERVE FEED / TOSS → STRIKE"
	feeder_label.font_size = 28
	feeder_label.pixel_size = 0.008
	feeder_label.modulate = Color("8bbdf4")
	feeder_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

# A red holographic wall along the half line, as high as a receive has to be to count: translucent, unlit, with scan lines and a bright top edge.
# It has no collision; the ball passes through it and only the height it passes at matters.
func _build_barrier() -> void:
	barrier = Node3D.new()
	barrier.name = "HeightBarrier"
	add_child(barrier)
	barrier.position = Vector3(16, 0, HALF)
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, CLEARANCE_HEIGHT)
	sheet.mesh = quad
	sheet.position.y = CLEARANCE_HEIGHT * 0.5
	sheet.material_override = _holo(Color(1.0, 0.12, 0.12, 0.13))
	barrier.add_child(sheet)
	var lines := 8
	for i in range(1, lines):
		var y := CLEARANCE_HEIGHT * float(i) / float(lines)
		barrier.add_child(_strip(Vector3(WIDTH, 0.012, 0.012), Vector3(0, y, 0), Color(1.0, 0.25, 0.2, 0.28)))
	barrier.add_child(_strip(Vector3(WIDTH, 0.06, 0.06), Vector3(0, CLEARANCE_HEIGHT, 0), Color(1.0, 0.3, 0.25, 0.95)))
	for x in [-WIDTH * 0.5, WIDTH * 0.5]:
		barrier.add_child(_strip(Vector3(0.05, CLEARANCE_HEIGHT, 0.05), Vector3(x, CLEARANCE_HEIGHT * 0.5, 0), Color(1.0, 0.3, 0.25, 0.7)))
	var label := Label3D.new()
	label.text = "CLEAR %.1f m" % CLEARANCE_HEIGHT
	label.font_size = 30
	label.pixel_size = 0.007
	label.modulate = Color(1.0, 0.45, 0.4)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, CLEARANCE_HEIGHT + 0.35, 0)
	barrier.add_child(label)

func _holo(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material

func _strip(size: Vector3, position_in_barrier: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position_in_barrier
	node.material_override = _holo(color)
	return node

func in_zone() -> bool:
	var p: Vector3 = lab.player.position - origin
	return p.x >= 13 and p.x <= 19 and p.z >= 0 and p.z <= LENGTH

# Where things are in the world, for callers that start from the station's own coordinates.
func start_world() -> Vector3:
	return START + origin

func target_world(index: int) -> Vector3:
	return TARGETS[index] + origin

func running() -> bool:
	return state in [State.WAITING, State.TOSS, State.SERVING, State.RETURNING]

func interact() -> void:
	if running():
		stop()
	elif in_zone():
		start()
	else:
		lab._message("Walk east along the blue path to the Serve Receive station, then press I.")

func start() -> void:
	if not in_zone():
		return
	state = State.WAITING
	streak = 0
	points = 0
	serves_sent = 0
	last_points = 0
	feed_bag.clear()
	timer = 1.5
	lab.ball_active = false
	lab.training_bots.active_action = -1
	lab.armed = false
	lab.charging = false
	lab.selected = 0
	lab.confirm_window = 0
	detail = "Get ready / receive into the scoring half / reach 8 points. Move + Space to dive."
	lab._message(detail)

func stop() -> void:
	state = State.IDLE
	lab.ball_active = false
	lab.training_bots.active_action = -1
	detail = "Drill stopped. I to restart while in the station."

func reset() -> void:
	state = State.IDLE
	streak = 0
	points = 0
	serves_sent = 0
	last_points = 0
	zone_was_entered = false
	detail = "Walk east along the blue path / I to start."

func tick(dt: float) -> void:
	if state == State.TOSS:
		toss_elapsed += dt
		striker.position = Vector3(16 + sin(feed_index * 1.5), lerpf(4.5, SERVE_CONTACT_HEIGHT + 0.18, clampf(toss_elapsed / TOSS_SECONDS, 0, 1)), SERVE_BASELINE_Z)
		if toss_elapsed >= TOSS_SECONDS:
			strike_feed()
		return
	feed_follow = maxf(0, feed_follow - dt)
	if is_instance_valid(striker):
		striker.position.y = lerpf(4.5, SERVE_CONTACT_HEIGHT - 0.3, feed_follow / 0.18)
	var inside := in_zone()
	if inside and not zone_was_entered and not running():
		lab.ball_active = false
		lab.training_bots.active_action = -1
		lab._message("Serve Receive station / press I to begin / receive into the scoring half for 8 points.")
	zone_was_entered = inside
	if not running():
		return
	timer -= dt
	if state == State.WAITING and timer <= 0:
		serve()
	elif state == State.RETURNING:
		_track_height()
		if timer <= 0:
			last_points = 0
			advance()

# Watches the returned ball cross the half line, and whether it went over the barrier. The height is where the ball path meets the plane.
func _track_height() -> void:
	if crossed:
		return
	var here: Vector3 = lab.ball.position
	if previous_ball != Vector3.INF and previous_ball.z - origin.z > HALF and here.z - origin.z <= HALF:
		var along := (previous_ball.z - origin.z - HALF) / maxf(previous_ball.z - here.z, 0.0001)
		_record_crossing(lerpf(previous_ball.y, here.y, along))
	previous_ball = here

func _record_crossing(height: float) -> void:
	crossed = true
	cross_height = height
	cleared = height >= CLEARANCE_HEIGHT
	if not cleared:
		detail = "TOO LOW / %.1f m at the half line, %.1f m needed / 0 points" % [height, CLEARANCE_HEIGHT]
		lab._message(detail)

func next_feed() -> int:
	# A test or tool can ask for one particular spot next.
	if force_next_feed >= 0:
		var forced := force_next_feed
		force_next_feed = -1
		return forced
	if feed_bag.is_empty():
		var previous := feed_index if serves_sent > 0 else -1
		feed_bag = range(TARGETS.size())
		# Fisher-Yates
		for i in range(feed_bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap = feed_bag[i]
			feed_bag[i] = feed_bag[j]
			feed_bag[j] = swap
		# The bag is dealt from the back; keep its first card off the one just served.
		if feed_bag.size() > 1 and feed_bag[feed_bag.size() - 1] == previous:
			var swap_index := rng.randi_range(0, feed_bag.size() - 2)
			var held = feed_bag[swap_index]
			feed_bag[swap_index] = feed_bag[feed_bag.size() - 1]
			feed_bag[feed_bag.size() - 1] = held
	return int(feed_bag.pop_back())

func serve() -> void:
	state = State.TOSS
	feed_index = next_feed()
	toss_elapsed = 0
	lab.ball.position = Vector3(16 + sin(feed_index * 1.5), TOSS_HEIGHT, SERVE_BASELINE_Z) + origin
	lab.ball_velocity = Vector3.UP * ((SERVE_CONTACT_HEIGHT - TOSS_HEIGHT) / TOSS_SECONDS + lab.GRAVITY * TOSS_SECONDS * 0.5)
	lab.ball_shot = {}
	lab.ball_active = true
	lab.outgoing = false
	lab.trail_points.clear()
	lab.contact_memory.fill(0.0)
	feeder_label.text = "TOSS → OVERHEAD STRIKE"
	detail = "%d / 8 points / TOSS / watch the overhead strike" % points
	lab._message(detail)

func strike_feed() -> void:
	state = State.SERVING
	feed_follow = 0.18
	feeder_label.text = "STRIKE / SERVE INCOMING"
	var incoming: Vector3 = lab.ball_velocity
	var feed := feed_index
	serves_sent += 1
	lab.attempts += 1
	lab.ball.position = Vector3(16 + sin(feed * 1.5) * 1.0, SERVE_CONTACT_HEIGHT, SERVE_BASELINE_Z) + origin
	var target: Vector3 = TARGETS[feed] + origin
	var horizontal_distance := Vector2(target.x - lab.ball.position.x, target.z - lab.ball.position.z).length()
	var duration := horizontal_distance / (22.0 + feed * 0.6)
	serve_duration = duration
	lab.ball_velocity = (target - lab.ball.position) / duration + Vector3.UP * float(lab.GRAVITY) * duration * 0.5
	lab.ball_shot = lab.ReceiveCharge.shot("serve", CHARGES[feed], "serve_receive_drill")
	lab.ball_active = true
	lab._emit_external_impact("drill_serve", 4, incoming, {"hit": true, "sweet": false})
	lab.outgoing = false
	lab.contacts = 0
	lab.side_contacts[0] = 0
	lab.side_contacts[1] = 0
	for action in range(4):
		lab.contact_memory[action] = 0.0
	lab.trail_points.clear()
	detail = "%d / 8 points / Serve %d / charge %d%% / receive %d–%d%%" % [points, serves_sent, CHARGES[feed] * 100, CHARGES[feed] * 100, minf(100, CHARGES[feed] * 100 + 15)]
	lab._message(detail)

func on_contact(action: int, charge_matched: bool = true) -> void:
	if state != State.SERVING:
		return
	if action != 0:
		fail("Receive required. I to retry.")
		return
	# A shank remains a physical receive. Only its landing determines points.
	state = State.RETURNING
	timer = 12.0
	last_points = 0
	crossed = false
	cleared = true
	cross_height = 0.0
	previous_ball = Vector3.INF
	# Received from inside the scoring half: the ball is already past the line, so its height now is the height that counts.
	if lab.ball.position.z - origin.z <= HALF:
		_record_crossing(lab.ball.position.y)
	lab.returns += 1
	detail = ("SHANK / " if not charge_matched else "RECEIVED / ") + "clear the red barrier and land in the scoring half: 1 point, far-right quarter: 2."
	lab._message(detail)

func landing_points(point_in_world: Vector3) -> int:
	var point := point_in_world - origin
	if point.x < 13 or point.x > 19 or point.z < 0 or point.z > HALF:
		return 0
	return 2 if point.x >= 16 and point.z <= TWO_LENGTH else 1

func on_ball_down(landing: Vector3 = Vector3.INF) -> void:
	if state == State.SERVING:
		fail("Missed serve. I to retry.")
	elif state == State.RETURNING:
		last_landing = lab.ball.position if landing == Vector3.INF else landing
		last_points = landing_points(last_landing) if cleared else 0
		points += last_points
		if last_points > 0:
			streak += 1
		advance()

func advance() -> void:
	lab.ball_active = false
	if points >= GOAL:
		state = State.COMPLETE
		earned_xp += 25
		lab.athlete.hp = minf(100, lab.athlete.hp + 20)
		lab.athlete.stamina = minf(100, lab.athlete.stamina + 15)
		detail = "COMPLETE / %d points / +25 lab XP, +20 HP, +15 STA. I to repeat." % points
	else:
		state = State.WAITING
		timer = 1.0
		detail = "+%d / %d of 8 points. Next serve in one second." % [last_points, points]
	lab._message(detail)

func fail(reason: String) -> void:
	state = State.FAILED
	lab.ball_active = false
	streak = 0
	points = 0
	serves_sent = 0
	last_points = 0
	detail = reason
	lab._message(reason)

func hud_text() -> String:
	if in_zone() or running():
		return "SERVE RECEIVE  /  %d OF 8 POINTS  /  I %s\n%s\nLab XP earned: %d" % [points, "STOP" if running() else "START / RETRY", detail, earned_xp]
	var distance := Vector2(lab.player.position.x - origin.x - START.x, lab.player.position.z - origin.z - START.z).length()
	return "SERVE RECEIVE STATION  →  EAST  /  %.0f m\nFollow the blue ground path. Walk into the blue court, then press I." % distance
