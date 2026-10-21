extends "res://scripts/map_drills.gd"
## Provisional cooperative practice: a receiving partner passes; the athlete sets into a goal.
const PASSES_REQUIRED := 3
const Basket := preload("res://scripts/drill_basket.gd")
const TARGETS := [Vector3(5,3.4,-7),Vector3(-5,3.4,-7),Vector3(4,3.8,-6),Vector3(-4,3.8,-6),Vector3(6,3.2,-8),Vector3(-6,3.2,-8)]
var anchor := Vector3.ZERO
var partner: Node3D
var partner_body: Node3D
var basket: Node3D
var goal_label: Label3D
var target_index := -1
var target_rng := RandomNumberGenerator.new()
var progress := 0
var waiting := false
var pose_time := 0.0

func setup(host: Node3D,_anchors: Dictionary = {}) -> void:
	lab = host
	target_rng.randomize()
	box_enabled = false
	spike_enabled = false
	lab.world_builder.box(self,Vector3(8,0.03,8),anchor-Vector3.UP*0.015,Color("315967"))
	lab.world_builder.world_label("TRANSITION SET / I START / 3 SETS THROUGH BASKET",anchor+Vector3(0,0.2,4.5),28,lab.GOLD)
	basket = Basket.new()
	add_child(basket)
	basket.build(lab.GOLD)
	goal_label = lab.world_builder.world_label("",anchor,24,lab.GOLD)
	setup_label = Label3D.new()
	setup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	setup_label.font_size = 26
	setup_label.pixel_size = 0.008
	setup_label.position = anchor+Vector3(0,3.4,4.0)
	add_child(setup_label)
	rack = preload("res://scripts/setup_rack.gd").new()
	rack.position = anchor+Vector3(-3.2,0,4.4)
	add_child(rack)
	rack.build(lab,lab.TEAL)
	move_target()
	partner = Node3D.new()
	partner.position = anchor+Vector3(-5,0,-5)
	add_child(partner)
	var build := {"name":"RECEIVE PARTNER","height":1.86,"span":1.86,"role":"L","dominant_hand":"Right"}
	var rig := preload("res://scripts/voli_visual.gd").build(lab,partner,"Avi",{},build)
	partner_body = rig.body
	partner.look_at(anchor)
	lab.world_builder.world_label("RECEIVE PARTNER",partner.position+Vector3.UP*2.3,22,lab.TEAL)
	detail = "I to start / receive partner passes to the pad; Set down through the gold basket from the front"

func target_world() -> Vector3:
	return basket.global_position

func move_target() -> void:
	var next := target_rng.randi_range(0,TARGETS.size()-2) if target_index >= 0 else target_rng.randi_range(0,TARGETS.size()-1)
	if target_index >= 0 and next >= target_index: next += 1
	target_index = next
	var center: Vector3 = anchor+TARGETS[target_index]
	var toward := Vector3(anchor.x-center.x,0,anchor.z-center.z).normalized()
	basket.place(center,Vector3.UP*0.8+toward*0.6)
	goal_label.position = center+Vector3.UP*1.15
	goal_label.text = "SET BASKET / %.1f m / ENTER DOWN + FROM FRONT"%center.y

func in_zone() -> bool:
	var p: Vector3 = lab.player.position-anchor
	return interaction_enabled and absf(p.x) <= 4 and absf(p.z) <= 4

func in_box_zone() -> bool: return false
func in_spike_zone() -> bool: return false
func update_one_way() -> void: pass
func holding_ball() -> bool: return false

# --- Setup (ball economy): give up a ball, the partner passes one ball per rep, three sets are not needed: five reps through the basket ----
func economy() -> bool:
	return lab.inventory.enabled

func setup_name() -> String:
	return "TRANSITION SET"

func _begin_setup_run() -> void:
	lab.station.stop()
	progress = 0

func _launch_setup_ball() -> void:
	spike_state = State.ACTIVE
	waiting = true
	timer = 1.0
	detail = "TRANSITION SET / rep %d of %d / %d errors / %d balls left / partner preparing" % [distributor.reps + 1, distributor.min_reps, distributor.errors, distributor.balls]
	lab._message(detail)

func interact() -> void:
	if economy():
		_interact_setup()
		return
	if running():
		reset()
		lab.ball_active = false
		detail = "Transition Set stopped / I to retry"
	elif in_zone():
		lab.station.stop()
		clear_preparation()
		progress = 0
		spike_state = State.ACTIVE
		waiting = true
		timer = 1.0
		detail = "Partner receiving / prepare Set and face the gold target"
	lab._message(detail)

func feed() -> void:
	waiting = false
	move_target()
	pose_time = 0.4
	var start: Vector3 = partner.position+Vector3(0,1.0,0)
	var destination: Vector3 = anchor+Vector3.UP*lab.athlete.reach()
	var flight := 1.25
	lab.ball.position = start
	lab.ball_velocity = (destination-start)/flight+Vector3.UP*lab.GRAVITY*flight*0.5
	lab.ball_shot = preload("res://scripts/receive_charge.gd").shot("receive",0.35,"transition_partner")
	lab.ball_active = true
	lab.outgoing = false
	lab.contacts = 0
	lab.side_contacts.assign([0,0])
	lab.trail_points.clear()
	lab.selected = 1
	timer = 10
	detail = "TRANSITION SET / %d of %d / Set the receive through the basket"%[progress,PASSES_REQUIRED]
	lab._message(detail)

func tick(dt: float) -> void:
	pose_time = maxf(0,pose_time-dt)
	preload("res://scripts/athlete_pose.gd").base(partner_body,0,0,0,true)
	if pose_time > 0:
		preload("res://scripts/pose_library.gd").apply(partner_body,preload("res://scripts/pose_library.gd").load_pose("planted_receive"))
	preload("res://scripts/athlete_pose.gd").ground_feet(partner_body)
	if not running(): return
	timer -= dt
	if timer <= 0:
		if waiting: feed()
		elif economy(): _spike_used(false, "player", "Transition Set ball timed out")
		else: fail("Transition Set timed out / I to retry")

func on_contact(action: int) -> void:
	if spike_state != State.ACTIVE or waiting: return
	if action != 1:
		if economy():
			_spike_used(false, "player", "Set the partner's receive")
			return
		fail("Set the partner's receive / I to retry")
		return
	spike_state = State.RETURNING
	timer = 8
	detail = "Set in flight / descend through the front of the basket"

func sweep_ball(previous: Vector3,dt: float) -> bool:
	if spike_state != State.RETURNING: return false
	var result: Dictionary = basket.step(previous,lab.ball.position,lab.ball_velocity,dt)
	lab.ball.position = result.position
	lab.ball_velocity = result.velocity
	if result.scored:
		_score()
		return true
	return false

func on_ball_down() -> void:
	if economy():
		if spike_state in [State.ACTIVE, State.RETURNING] and not waiting:
			_spike_used(false, "player", "Missed the basket")
		return
	fail("Missed basket / Set must enter down through its front / I to retry")

func _score() -> void:
	if economy():
		progress += 1
		_spike_used(true, "player", "")
		return
	lab.ball_active = false
	progress += 1
	if progress >= PASSES_REQUIRED:
		spike_state = State.COMPLETE
		reward(30,20,10)
		detail = "TRANSITION SET COMPLETE / +30 XP / +20 HP / +10 STA / I to repeat"
	else:
		spike_state = State.ACTIVE
		waiting = true
		timer = 1
		detail = "Good set / %d of %d / partner preparing"%[progress,PASSES_REQUIRED]
	lab._message(detail)

func fail(reason: String) -> void:
	spike_state = State.FAILED
	lab.ball_active = false
	detail = reason
	lab._message(reason)

func reset() -> void:
	spike_state = State.IDLE
	progress = 0
	waiting = false
	detail = "I to start Transition Set"

func hud_text() -> String:
	return "TRANSITION SET / %d OF %d\n%s"%[progress,PASSES_REQUIRED,detail]
