extends "res://scripts/transition_set_drill.gd"
## Set repeatedly into a wall target while countersteering a rotating balance ball.
const PAD_RADIUS := 1.1
const BALL_TOP := 1.3
const MAX_LEAN := 0.58
var wobble_time := 0.0
var lean := Vector2.ZERO
var lean_velocity := Vector2.ZERO
var balance_ball: MeshInstance3D
var wall_target := Vector3.ZERO
var mounted := false

func setup(host: Node3D, anchors: Dictionary = {}) -> void:
	super.setup(host, anchors)
	partner.hide()
	basket.hide()
	# Replace the inherited instructions while retaining the shared ball economy.
	for child in lab.get_children():
		if child is Label3D and child.text.begins_with("TRANSITION SET / I START") and child.position.distance_to(anchor) < 7:
			child.text = "BALANCE BALL / SET THE WALL TARGET / WASD COUNTERBALANCE"
		if child is Label3D and child.text == "RECEIVE PARTNER" and child.position.distance_to(anchor) < 9:
			child.hide()
	balance_ball = lab.world_builder.sphere(self, 0.65, anchor + Vector3(0, 0.65, 0), Color("8c72c4"))
	for i in range(3):
		var ring: MeshInstance3D = lab.world_builder.ring(0.66, Color("e4d9ff"))
		ring.reparent(balance_ball, false)
		ring.rotation = Vector3(PI / 2 if i == 0 else 0.0, 0.0, PI / 2 if i == 2 else 0.0)
	lab.world_builder.box(self, Vector3(5.0, 5.0, 0.16), anchor + Vector3(0, 2.5, -6), Color("465263"))
	lab.world_builder.box(self, Vector3(1.6, 1.6, 0.04), wall_target, Color("ffce73"))
	detail = "I to start / set the gold wall target / WASD counter rotation; excessive lean causes a fall"

func setup_name() -> String:
	return "BALANCE BALL SETTING"

func move_target() -> void:
	wall_target = anchor + Vector3(0, 3.3, -5.88)
	goal_label.position = wall_target + Vector3.UP * 1.2
	goal_label.text = "SET WALL TARGET"

func target_world() -> Vector3:
	return wall_target

func in_pad() -> bool:
	var p: Vector3 = lab.player.position - anchor
	return Vector2(p.x, p.z).length() <= PAD_RADIUS and p.y <= BALL_TOP + 0.2

func wobble_amplitude() -> float:
	var rating: float = preload("res://scripts/stat_tuning.gd").rating(lab.athlete.build, "stability")
	return lerpf(0.75, 0.28, clampf((rating - 50.0) / 49.0, 0.0, 1.0))

func mount() -> void:
	mounted = true
	lean = Vector2.ZERO
	lean_velocity = Vector2.ZERO
	wobble_time = 0.0
	lab.player.position = anchor + Vector3.UP * BALL_TOP
	lab.motion.jump_charge = -1
	lab.motion.jumped = false

func _begin_setup_run() -> void:
	super._begin_setup_run()
	mount()

func interact() -> void:
	super.interact()
	if running() and not mounted: mount()
	elif not running(): mounted = false

func drill_input(event: InputEvent) -> bool:
	return running() and mounted and event is InputEventKey and event.keycode == KEY_SPACE

func drill_motion(dt: float, move: Vector3) -> bool:
	if not running() or not mounted: return false
	wobble_time += dt
	var amplitude := wobble_amplitude()
	var drive := Vector2(sin(wobble_time * 1.7), cos(wobble_time * 1.3 + 0.6)) * amplitude
	lean_velocity += (drive + lean * 0.9 + Vector2(move.x, move.z) * 1.8 - lean_velocity * 1.7) * dt
	lean += lean_velocity * dt
	var spin := amplitude * (0.7 + 0.35 * sin(wobble_time * 0.8))
	var turn := (spin + move.x * 0.3) * dt
	lab.camera_rig.facing_yaw += turn
	lab.camera_rig.view_yaw += turn
	balance_ball.rotate_y(spin * dt)
	balance_ball.rotate_x(lean_velocity.y * dt)
	balance_ball.rotate_z(-lean_velocity.x * dt)
	lab.player.position = anchor + Vector3(lean.x * 0.5, BALL_TOP, lean.y * 0.5)
	lab.player.velocity = Vector3.ZERO
	if lab.charging: lab.charge = minf(1.0, lab.charge + dt / 0.85)
	lab.athlete.recover(dt, move.length_squared() < 0.01)
	if lean.length() > MAX_LEAN:
		mounted = false
		lab.player.position = anchor + Vector3(lean.normalized().x * 1.4, BALL_TOP, lean.normalized().y * 1.4)
		if economy(): _spike_used(false, "player", "Fell off the balance ball")
		else: fail("Fell / keep your lean inside the ball / I to retry")
	return true

func feed() -> void:
	if not mounted: mount()
	waiting = false
	lab.selected = 1
	lab.motion.airborne_action = 1
	var destination: Vector3 = lab.player.position + Vector3.UP * lab.athlete.reach()
	var flight := 1.25
	lab.ball.position = wall_target
	lab.ball_velocity = (destination - wall_target) / flight + Vector3.UP * lab.GRAVITY * flight * 0.5
	lab.ball_shot = preload("res://scripts/receive_charge.gd").shot("receive", 0.35, "balance_wall")
	lab.ball_active = true
	lab.outgoing = false
	lab.contacts = 0
	lab.side_contacts.assign([0, 0])
	lab.trail_points.clear()
	timer = 10.0
	detail = "Set the wall target / WASD to counterbalance / lean %.0f%%" % (100 * lean.length() / MAX_LEAN)

func on_contact(action: int) -> void:
	super.on_contact(action)
	if spike_state == State.RETURNING: detail = "Set in flight / hit the gold wall target"

func sweep_ball(previous: Vector3, _dt: float) -> bool:
	if spike_state != State.RETURNING: return false
	var current: Vector3 = lab.ball.position
	if previous.z > wall_target.z and current.z <= wall_target.z:
		var t := (wall_target.z - previous.z) / (current.z - previous.z)
		var hit := previous.lerp(current, t)
		if absf(hit.x - wall_target.x) <= 0.8 and absf(hit.y - wall_target.y) <= 0.8:
			_score()
			return true
		if economy(): _spike_used(false, "player", "Missed the wall target")
		else: fail("Missed wall target / I to retry")
		return true
	return false

func on_ball_down() -> void:
	if economy():
		if not waiting: _spike_used(false, "player", "Set missed the wall target")
	else: fail("Set missed the wall target / I to retry")

func apply_drill_pose() -> void:
	if not running() or not mounted: return
	lab.body.rotation.x += lean.y
	lab.body.rotation.z -= lean.x

func reset() -> void:
	super.reset()
	mounted = false
	lean = Vector2.ZERO
	lean_velocity = Vector2.ZERO
	detail = "I to start Balance Ball Setting"

func hud_text() -> String:
	return "BALANCE BALL SETTING / %d OF %d / LEAN %.0f%%\n%s" % [progress, PASSES_REQUIRED, 100 * lean.length() / MAX_LEAN, detail]

func _launch_setup_ball() -> void:
	super._launch_setup_ball()
	detail = "BALANCE BALL / wall feed preparing / WASD counterbalance"

func _score() -> void:
	super._score()
	if not economy():
		detail = "BALANCE BALL COMPLETE" if spike_state == State.COMPLETE else "Good wall set / %d of %d" % [progress, PASSES_REQUIRED]
		lab._message(detail)
