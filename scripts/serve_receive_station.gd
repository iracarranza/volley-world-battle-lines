extends Node3D

const CENTER := Vector3(16, 0, 6.5)
const SERVE_BASELINE_Z := -10.0
const SERVE_CONTACT_HEIGHT := 3.60
const CHARGES := [0.45, 0.55, 0.65, 0.60, 0.70, 0.75]
const WIDTH := 6.0
const LENGTH := 13.0
const HALF := LENGTH * 0.5
const GOAL := 8
const TOSS_SECONDS := 0.60
const TOSS_HEIGHT := 1.80
var toss_elapsed := 0.0
var feed_index := 0
var feed_follow := 0.0
var striker: MeshInstance3D
var feeder_label: Label3D
const START := Vector3(13.5, 0, 10.5)
const TARGETS := [Vector3(14, 0.105, 8), Vector3(18, 0.105, 9), Vector3(15, 0.105, 11), Vector3(17.5, 0.105, 7), Vector3(13.8, 0.105, 10), Vector3(18.2, 0.105, 12)]
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
# Where the whole station sits in the world. Zero in the Contact Lab; a hosting scene moves it (LabHost: lab.station_origin).
var origin := Vector3.ZERO

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	origin = lab.station_origin
	position = origin
	lab.box(self, Vector3(WIDTH, 0.12, LENGTH), Vector3(16, -0.06, HALF), Color("304d69"))
	for x in [13.0, 19.0]:
		lab.box(self, Vector3(0.06, 0.025, LENGTH), Vector3(x, 0.025, HALF), Color("91b8f2"))
	for z in [0.0, HALF, LENGTH]:
		lab.box(self, Vector3(WIDTH, 0.025, 0.06), Vector3(16, 0.025, z), Color("91b8f2"))
	lab.box(self, Vector3(WIDTH, 0.015, HALF), Vector3(16, 0.012, HALF * 0.5), Color("386b70"))
	lab.box(self, Vector3(WIDTH * 0.5, 0.018, HALF), Vector3(17.5, 0.023, HALF * 0.5), Color("78703c"))
	for x in [16.0]:
		lab.box(self, Vector3(0.04, 0.025, HALF), Vector3(x, 0.04, HALF * 0.5), Color("b7d6bd"))
	lab.world_label("RECEIVE HERE / 1 PT", Vector3(14.5, 0.15, 3.25) + origin, 24, Color("9ce5d8"))
	lab.world_label("2 PTS", Vector3(17.5, 0.15, 3.25) + origin, 28, Color("ffe28a"))
	# A continuous traversable connection, no teleport or scene change.
	for x in range(5, 13):
		lab.box(self, Vector3(0.6, 0.025, 0.14), Vector3(x, 0.025, 6), Color("8bbdf4"))
	lab.world_label("SERVE RECEIVE  /  8 POINTS", Vector3(16, 0.4, -0.4) + origin, 42, Color("8bbdf4"))
	lab.world_label("SERVE RECEIVE  →", Vector3(6.5, 0.2, 5) + origin, 30, Color("8bbdf4"))
	lab.world_label("I / START OR RETRY", START + Vector3(0, 0.2, 1.5) + origin, 27, Color("cbdfff"))
	marker = lab.ring(1.25, Color("8bbdf4"))
	marker.position = START + Vector3.UP * 0.04 + origin
	for target in TARGETS:
		var target_ring: MeshInstance3D = lab.ring(0.38, Color("547da4"))
		target_ring.position = Vector3(target.x, 0.025, target.z) + origin
	var machine: MeshInstance3D = lab.box(self, Vector3(1.0, 1.3, 1), Vector3(16, 0.65, SERVE_BASELINE_Z), Color("607f9e"))
	lab.box(self, Vector3(0.15, 3.6, 0.15), Vector3(15.35, 2.45, SERVE_BASELINE_Z), Color("607f9e"))
	striker = lab.box(self, Vector3(0.65, 0.18, 0.55), Vector3(16, 4.5, SERVE_BASELINE_Z), Color("ffb46e"))
	feeder_label = Label3D.new()
	add_child(feeder_label)
	feeder_label.position = machine.position + Vector3.UP * 4.7
	feeder_label.text = "JUMP SERVE FEED / TOSS → STRIKE"
	feeder_label.font_size = 28
	feeder_label.pixel_size = 0.008
	feeder_label.modulate = Color("8bbdf4")
	feeder_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

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
	elif state == State.RETURNING and timer <= 0:
		last_points = 0
		advance()

func serve() -> void:
	state = State.TOSS
	feed_index = serves_sent % TARGETS.size()
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
	lab.returns += 1
	detail = ("SHANK / " if not charge_matched else "RECEIVED / ") + "land in the opposite half: 1 point, far-right quarter: 2."
	lab._message(detail)

func landing_points(point_in_world: Vector3) -> int:
	var point := point_in_world - origin
	if point.x < 13 or point.x > 19 or point.z < 0 or point.z > HALF:
		return 0
	return 2 if point.x >= 16 else 1

func on_ball_down(landing: Vector3 = Vector3.INF) -> void:
	if state == State.SERVING:
		fail("Missed serve. I to retry.")
	elif state == State.RETURNING:
		last_landing = lab.ball.position if landing == Vector3.INF else landing
		last_points = landing_points(last_landing)
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
