extends Node3D

# Provisional, world-space drills using the same movement and action contacts.
const BOX_START := Vector3(-36, 0, 13)
const SPIKE_START := Vector3(-16, 0, 10)
# A tower of one-way platforms (you pass up through them and land on top), a few metres across. Every layer is climbed with an
# attack jump: run the length of the deck below, hold Space, and release at the charge that layer asks for. A longer hold gives a
# higher jump (a release at no charge is 0.6 of the standing leap, a full hold 1.2), and each layer is higher above the one below than
# the last release can reach, so each needs more charge than the one before. Layer heights are set from this build's own leap.
# Decks are long enough for the 3.3 m run-up, and the jump goes straight up through the next deck.
const FIRST_ATTACK := 0         # every layer needs an attack approach
const TOWER_X := -36.0
const TOWER_Z := 4.0
const DECK_SIZE := Vector2(1.8, 5.0)
# The jump factor each layer asks of the release. A layer sits halfway between what the factor before it reaches and what this one
# does, so the previous charge falls short and this one clears it. The first starts from the 0.6 of a standing jump.
const LAYER_FACTORS := [0.70, 0.88, 1.04, 1.19]
const STANDING_FACTOR := 0.60
# Which side of a platform is solid: from above only. A platform is passable until the feet are on or over its top.
const ONE_WAY_MARGIN := 0.02
const ApproachRun := preload("res://scripts/approach_run.gd")
const SPIKE_GOAL := Vector3(-16, 0.105, -4)
const SPIKE_HEIGHT_OFFSET := 1.40
const SPIKE_WIDTH := 6.0
const RUNWAY_START := Vector3(-16, 0.035, 10.5)
const RUNWAY_END := Vector3(-16, 0.035, 7.5)
const GOAL_RADIUS := 2.8
const SPIKES_REQUIRED := 3
enum State { IDLE, ACTIVE, RETURNING, COMPLETE, FAILED }
var lab: Node3D
var box_state := State.IDLE
var spike_state := State.IDLE
var box_progress := 0
var spike_progress := 0
var earned_xp := 0
var timer := 0.0
var detail := "I to start nearby drill"
var box_markers: Array[MeshInstance3D] = []
var attack_markers: Array[MeshInstance3D] = []
var layer_charges: Array = []     # the release charge each layer asks for
var attack_group: Node3D
var one_way: Array = []          # {body, top, solid}
var attack_one_way: Array = []
var attack_tops: Array = []
var built_for := ""
var spike_goal: MeshInstance3D
# Where the two drills sit in the world. Zero in the Contact Lab; a hosting scene moves them (lab.box_origin, lab.spike_origin). Everything
# below is written in each drill's own coordinates.
var box_anchor := Vector3.ZERO
var spike_anchor := Vector3.ZERO
var box_root: Node3D
var spike_root: Node3D

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	box_anchor = lab.box_origin
	spike_anchor = lab.spike_origin
	box_root = Node3D.new()
	box_root.position = box_anchor
	add_child(box_root)
	spike_root = Node3D.new()
	spike_root.position = spike_anchor
	add_child(spike_root)
	lab.world_builder.box(box_root, Vector3(20, 0.03, 28), Vector3(-34, -0.015, 5), Color("34423d"))
	attack_group = Node3D.new()
	box_root.add_child(attack_group)
	_build_attack_decks()
	lab.world_builder.world_label("BOX JUMP / ONE-WAY TOWER", Vector3(-36, 0.15, 17) + box_anchor, 34, lab.GOLD)
	lab.world_builder.world_label("I START / LAND ON 1–4 IN ORDER / EVERY LAYER IS AN ATTACK JUMP", BOX_START + box_anchor, 24, lab.GOLD)
	lab.world_builder.world_label("CHARGE ATTACK / RUN THE DECK / HOLD SPACE LONGER FOR EACH LAYER, RELEASE TO JUMP", Vector3(TOWER_X, 0.15, 9.2) + box_anchor, 20, Color("ffb46e"))
	lab.world_builder.box(spike_root, Vector3(SPIKE_WIDTH, 0.03, 25), Vector3(-16, -0.015, 5), Color("493b3c"))
	lab.world_builder.world_label("SPIKE TRAINER / 3 JUMP HITS", Vector3(-16, 0.15, 16) + spike_anchor, 34, Color("ffb46e"))
	lab.world_builder.world_label("I START / JUMP + ATTACK INTO GOLD TARGET", SPIKE_START + Vector3(0, 0.1, 3) + spike_anchor, 24, Color("ffb46e"))
	# A floor runway with start/plant stripes and the long-short-inward rhythm.
	lab.world_builder.box(spike_root, Vector3(1.5, 0.015, RUNWAY_START.z - RUNWAY_END.z), (RUNWAY_START + RUNWAY_END) * 0.5, Color("765842"))
	for z in [RUNWAY_START.z, RUNWAY_END.z]:
		lab.world_builder.box(spike_root, Vector3(1.8, 0.02, 0.10), Vector3(-16, 0.05, z), lab.GOLD)
	for step in range(3):
		var z: float = lerpf(RUNWAY_START.z, RUNWAY_END.z, [0.58, 0.82, 1.0][step])
		var x: float = -16.0 + [0.18, -0.18, 0.055][step]
		lab.world_builder.box(spike_root, Vector3(0.18, 0.025, 0.34), Vector3(x, 0.06, z), lab.GOLD)
	lab.world_builder.world_label("APPROACH START / FACE BALL", RUNWAY_START + Vector3(0, 0.1, 0.5) + spike_anchor, 21, lab.GOLD)
	lab.world_builder.world_label("PLANT / JUMP", RUNWAY_END + Vector3(0, 0.1, -0.3) + spike_anchor, 20, lab.GOLD)
	spike_goal = lab.world_builder.ring(GOAL_RADIUS, lab.GOLD)
	spike_goal.position = SPIKE_GOAL + Vector3.UP * 0.02 + spike_anchor
	for x in range(-29, -6, 2):
		lab.world_builder.box(box_root if x < -22 else spike_root, Vector3(0.6, 0.025, 0.14), Vector3(x, 0.025, 14), lab.GOLD)
	lab.world_builder.world_label("← SPIKE TRAINER / BOX JUMP", Vector3(-7, 0.1, 13) + spike_anchor, 25, lab.GOLD)

# A slab you can pass up through and land on. The footprint is solid only while the feet are on or above the top,
# decided each physics frame in update_one_way().
func _add_deck(parent: Node3D, top: Vector3, footprint: Vector2, tint: Color) -> Dictionary:
	var thickness := 0.3
	var visual: MeshInstance3D = lab.world_builder.box(parent, Vector3(footprint.x, thickness, footprint.y), Vector3(top.x, top.y - thickness * 0.5, top.z), tint)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x, thickness, footprint.y)
	collision.shape = shape
	body.position = visual.position
	body.add_child(collision)
	parent.add_child(body)
	return {"body": body, "top": top.y, "solid": true}

# Called every physics frame before the player moves.
func update_one_way() -> void:
	if lab == null:
		return
	var feet: float = lab.player.position.y
	if feet < 0.0 or not in_box_zone():
		return
	# Solid only to someone standing or coming down onto it. While the player is still rising it stays open, even once
	# the feet are above the top, so passing up through it never registers as a landing.
	var settling: bool = lab.player.velocity.y <= 0.01
	for platform in one_way + attack_one_way:
		var solid: bool = settling and feet >= float(platform.top) - ONE_WAY_MARGIN
		if solid == bool(platform.solid):
			continue
		platform.solid = solid
		if solid:
			lab.player.remove_collision_exception_with(platform.body)
		else:
			lab.player.add_collision_exception_with(platform.body)

# Height of each layer above the one below for this athlete: halfway between what the previous layer's factor and this one's reach.
func layer_steps_for(athlete: RefCounted) -> Array:
	var base: float = athlete.fresh_leap()
	var steps := []
	var previous := STANDING_FACTOR
	for factor in LAYER_FACTORS:
		steps.append(base * 0.5 * (previous + float(factor)))
		previous = float(factor)
	return steps

func course_tops() -> Array:
	return attack_tops

func course_sizes() -> Array:
	var sizes := []
	for i in range(attack_tops.size()):
		sizes.append(DECK_SIZE)
	return sizes

# The layers, rebuilt to this athlete's jump.
func _build_attack_decks() -> void:
	for platform in attack_one_way:
		lab.player.remove_collision_exception_with(platform.body)
	attack_one_way.clear()
	for child in attack_group.get_children():
		attack_group.remove_child(child)
		child.queue_free()
	for marker in attack_markers:
		marker.queue_free()
	attack_markers.clear()
	attack_tops.clear()
	layer_charges.clear()
	built_for = String(lab.athlete.build.get("name", ""))
	var steps := layer_steps_for(lab.athlete)
	var height := 0.0
	for k in range(LAYER_FACTORS.size()):
		height += float(steps[k])
		var top := Vector3(TOWER_X, height, TOWER_Z)
		var charge: float = lab.athlete.charge_for_factor(float(LAYER_FACTORS[k]))
		layer_charges.append(charge)
		attack_one_way.append(_add_deck(attack_group, top, DECK_SIZE, Color("a8623a").lightened(k * 0.06)))
		var mark: MeshInstance3D = lab.world_builder.ring(0.6, Color("ffb46e"))
		mark.position = top + Vector3.UP * 0.035 + box_anchor
		attack_markers.append(mark)
		var label := Label3D.new()
		label.text = "%d   HOLD %d%%" % [k + 1, roundi(100.0 * charge / ApproachRun.LAUNCH_START)]
		label.position = top + Vector3.UP * 0.12
		label.font_size = 38
		label.pixel_size = 0.007
		label.modulate = Color("ffb46e")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		attack_group.add_child(label)
		attack_tops.append(top)

func in_box_zone() -> bool:
	var p: Vector3 = lab.player.position - box_anchor
	return p.x >= -43 and p.x <= -25 and p.z >= -4 and p.z <= 20

func in_spike_zone() -> bool:
	var p: Vector3 = lab.player.position - spike_anchor
	return p.x >= -19 and p.x <= -13 and p.z >= 0 and p.z <= 17

# Where things are in the world, for callers that start from a drill's own coordinates.
func box_start_world() -> Vector3:
	return BOX_START + box_anchor

func spike_start_world() -> Vector3:
	return SPIKE_START + spike_anchor

func course_top_world(index: int) -> Vector3:
	return (course_tops()[index] as Vector3) + box_anchor

func in_zone() -> bool:
	return in_box_zone() or in_spike_zone()

# Only the hitting drill owns a ball and suppresses court bot interception.
func running() -> bool:
	return spike_state in [State.ACTIVE, State.RETURNING]

func holding_ball() -> bool:
	return spike_state == State.ACTIVE

func interact() -> void:
	if in_box_zone():
		if box_state == State.ACTIVE:
			box_state = State.IDLE
			detail = "Box Jump stopped / I to retry"
		else:
			start_box()
	elif in_spike_zone():
		if running():
			spike_state = State.IDLE
			lab.ball_active = false
			detail = "Spike Trainer stopped / I to retry"
		else:
			start_spike()
	lab._message(detail)

func clear_preparation() -> void:
	lab.ball_active = false
	lab.training_bots.active_action = -1
	lab.armed = false
	lab.charging = false
	lab.confirm_window = 0
	lab.motion.jump_charge = -1
	lab.motion.approach_bound = false
	lab.motion.approach_release_pending = false

func start_box() -> void:
	if not in_box_zone():
		return
	lab.station.stop()
	spike_state = State.IDLE
	clear_preparation()
	box_state = State.ACTIVE
	box_progress = 0
	detail = "BOX JUMP / land on 1–4 in order. Every layer is an attack jump: run the deck, charge Attack, hold Space longer for each layer and release. Falling to the ground resets the run."

func start_spike() -> void:
	if not in_spike_zone():
		return
	lab.station.stop()
	box_state = State.IDLE
	clear_preparation()
	spike_progress = 0
	load_spike()

func load_spike() -> void:
	spike_state = State.ACTIVE
	timer = 20.0
	lab.selected = 2
	lab.armed = false
	lab.charging = false
	lab.confirm_window = 0
	lab.contacts = 0
	lab.side_contacts.assign([0, 0])
	lab.contact_memory.assign([0.0, 0.0, 0.0, 0.0])
	lab.ball.position = Vector3(-16 + [0.0, -0.6, 0.6][spike_progress], lab.athlete.reach() + SPIKE_HEIGHT_OFFSET, 7) + spike_anchor
	lab.ball_velocity = Vector3.ZERO
	lab.ball_shot = {}
	lab.shadow.position = Vector3(lab.ball.position.x, 0.03, lab.ball.position.z)
	lab.ball_active = true
	lab.outgoing = false
	lab.trail_points.clear()
	detail = "SPIKE %d / 3 / suspended ball: jump, confirm Attack, land in gold target" % (spike_progress + 1)
	lab._message(detail)

func tick(dt: float) -> void:
	# In the tower an attack jump is cleared by how long Space was held, not by the speed it happened to be released at.
	lab.motion.attack_energy_conversion = not in_box_zone()
	if box_state == State.ACTIVE:
		if not in_box_zone():
			box_state = State.FAILED
			detail = "Left Box Jump course / I to retry"
		elif lab.player.is_on_floor():
			var next: Vector3 = course_tops()[box_progress]
			var half: Vector2 = course_sizes()[box_progress] * 0.5
			var p: Vector3 = lab.player.position - box_anchor
			if absf(p.x - next.x) <= half.x - 0.1 and absf(p.z - next.z) <= half.y - 0.1 and absf(p.y - next.y) < 0.16:
				box_progress += 1
				lab.athlete.spend(3.0)
				if box_progress == course_tops().size():
					box_state = State.COMPLETE
					reward(35, 18, 10)
					detail = "BOX JUMP COMPLETE / +35 lab XP / +18 HP / +10 STA / I to repeat"
				else:
					detail = "BOX JUMP / %d of %d / next landing: %d%s" % [box_progress, course_tops().size(), box_progress + 1, " (hold Space for %d%%)" % roundi(100.0 * float(layer_charges[box_progress]) / ApproachRun.LAUNCH_START) if box_progress < layer_charges.size() else ""]
				lab._message(detail)
			elif box_progress > 0 and p.y < 0.2:
				box_state = State.FAILED
				box_progress = 0
				detail = "Fell to ground / Box Jump run lost / I to retry"
				lab._message(detail)
	if built_for != String(lab.athlete.build.get("name", "")):
		_build_attack_decks()
	for i in range(box_markers.size()):
		box_markers[i].visible = box_state != State.ACTIVE or i == box_progress
	for i in range(attack_markers.size()):
		attack_markers[i].visible = box_state != State.ACTIVE or FIRST_ATTACK + i == box_progress
	if running():
		if not in_spike_zone():
			fail_spike("Left Spike Trainer area / I to retry")
			return
		timer -= dt
		if timer <= 0:
			fail_spike("Spike Trainer timed out / I to retry")

func on_contact(action: int) -> void:
	if spike_state != State.ACTIVE:
		return
	if action != 2 or not lab.motion.jumped or lab.motion.airborne_action != 2:
		fail_spike("A jumping Attack is required / I to retry")
		return
	spike_state = State.RETURNING
	timer = 5.0
	detail = "SPIKE IN FLIGHT / land inside the gold circle"
	lab._message(detail)

func on_ball_down() -> void:
	if spike_state != State.RETURNING:
		fail_spike("Missed suspended spike / I to retry")
		return
	var offset := Vector2(lab.ball.position.x - spike_anchor.x - SPIKE_GOAL.x, lab.ball.position.z - spike_anchor.z - SPIKE_GOAL.z)
	if offset.length() > GOAL_RADIUS:
		fail_spike("Spike missed gold target / I to retry")
		return
	spike_progress += 1
	lab.ball_active = false
	lab.athlete.hp = minf(100, lab.athlete.hp + 5)
	if spike_progress == SPIKES_REQUIRED:
		spike_state = State.COMPLETE
		reward(30, 20, 10)
		detail = "SPIKE TRAINER COMPLETE / +30 lab XP / +20 HP / +10 STA / I to repeat"
		lab._message(detail)
	else:
		load_spike()

func fail_spike(reason: String) -> void:
	spike_state = State.FAILED
	lab.ball_active = false
	detail = reason
	lab._message(reason)

func reward(xp: int, hp: float, stamina: float) -> void:
	earned_xp += xp
	lab.athlete.hp = minf(100, lab.athlete.hp + hp)
	lab.athlete.stamina = minf(lab.athlete.max_stamina(), lab.athlete.stamina + stamina)

func reset() -> void:
	box_state = State.IDLE
	spike_state = State.IDLE
	box_progress = 0
	spike_progress = 0
	detail = "I to start nearby drill"

func hud_text() -> String:
	return "%s / I START / STOP / RETRY\n%s\nLab XP earned: %d" % ["BOX JUMP PARKOUR" if in_box_zone() else "SPIKE TRAINER", detail, earned_xp]
