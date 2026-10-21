extends "res://scripts/map_drills.gd"
## Provisional cooperative practice: a receiving partner passes; the athlete sets into a goal.
const PASSES_REQUIRED := 3
const TARGET_RADIUS := 2.0
var anchor := Vector3.ZERO
var partner: Node3D
var partner_body: Node3D
var goal: MeshInstance3D
var progress := 0
var waiting := false
var pose_time := 0.0

func setup(host: Node3D,_anchors: Dictionary = {}) -> void:
	lab = host
	box_enabled = false
	spike_enabled = false
	lab.world_builder.box(self,Vector3(8,0.03,8),anchor-Vector3.UP*0.015,Color("315967"))
	lab.world_builder.world_label("TRANSITION SET / I START / 3 SETS INTO GOLD",anchor+Vector3(0,0.2,4.5),28,lab.GOLD)
	goal = lab.world_builder.ring(TARGET_RADIUS,lab.GOLD)
	goal.position = target_world()
	lab.world_builder.world_label("SET TARGET",target_world()+Vector3.UP*0.2,24,lab.GOLD)
	partner = Node3D.new()
	partner.position = anchor+Vector3(-5,0,-5)
	add_child(partner)
	var build := {"name":"RECEIVE PARTNER","height":1.86,"span":1.86,"role":"L","dominant_hand":"Right"}
	var rig := preload("res://scripts/voli_visual.gd").build(lab,partner,"Avi",{},build)
	partner_body = rig.body
	partner.look_at(anchor)
	lab.world_builder.world_label("RECEIVE PARTNER",partner.position+Vector3.UP*2.3,22,lab.TEAL)
	detail = "I to start / receive partner passes to the pad; Set into the gold circle"

func target_world() -> Vector3:
	return anchor+Vector3(0,0.105,-8)

func in_zone() -> bool:
	var p: Vector3 = lab.player.position-anchor
	return interaction_enabled and absf(p.x) <= 4 and absf(p.z) <= 4

func in_box_zone() -> bool: return false
func in_spike_zone() -> bool: return false
func update_one_way() -> void: pass
func holding_ball() -> bool: return false

func interact() -> void:
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
	detail = "TRANSITION SET / %d of %d / Set the receive into gold"%[progress,PASSES_REQUIRED]
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
		else: fail("Transition Set timed out / I to retry")

func on_contact(action: int) -> void:
	if spike_state != State.ACTIVE or waiting: return
	if action != 1:
		fail("Set the partner's receive / I to retry")
		return
	spike_state = State.RETURNING
	timer = 8
	detail = "Set in flight / land inside gold"

func on_ball_down() -> void:
	if spike_state != State.RETURNING:
		fail("Missed partner's receive / I to retry")
		return
	var delta: Vector3 = lab.ball.position-target_world()
	if Vector2(delta.x,delta.z).length() > TARGET_RADIUS:
		fail("Set missed gold / I to retry")
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
