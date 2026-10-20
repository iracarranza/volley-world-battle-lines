extends Node3D

# Interactive bot pads. Stand on a pad and press I to spawn a bot at the pad's bot spot; press I again to despawn it.
# A spawned bot repeats its action every LOOP seconds: it spawns a ball at its sweet spot, winds up, and hits the
# ball toward the pad using the pad's configuration (charge, timing, aim). The balls are the pad's own simple
# ballistic balls; this file never touches the lab ball or the contact input/output framework, and it only uses
# BotAnimation's public update/contact calls for the body.
const Visual := preload("res://scripts/voli_visual.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const BotAnimation := preload("res://scripts/bot_animation.gd")
const ACTIONS := ["RECEIVE", "SET", "ATTACK", "BLOCK"]
const COLORS := [Color("54ead0"), Color("ac9df2"), Color("ffce73"), Color("8bbdf4")]
const PAD_RADIUS := 1.5
# Behind the away side of the court, clear of the lanes' bases, drills and the station.
const PAD_Z := -22.0
const BOT_DISTANCE := 5.0
const PAD_X := [-9.0, -3.0, 3.0, 9.0]
const LOOP := 5.0
const WINDUP := 1.2
const BALL_RADIUS := 0.105
const GRAVITY := 9.81
const LAND_LINGER := 1.0
const DEFAULTS := {"charge": 0.65, "timing": 0.0, "aim": 0.0}
# key: [minimum, maximum, step]
const LIMITS := {"charge": [0.0, 1.0, 0.05], "timing": [-0.30, 0.30, 0.05], "aim": [-60.0, 60.0, 5.0]}
var lab: Node3D
var pads: Array[Dictionary] = []
var animation := BotAnimation.new()

func setup(owner_lab: Node3D) -> void:
	lab = owner_lab
	for index in range(PAD_X.size()):
		var position := Vector3(PAD_X[index], 0.0, PAD_Z)
		var color: Color = COLORS[index]
		var disc: MeshInstance3D = lab.world_builder.box(self, Vector3(PAD_RADIUS * 2.0, 0.03, PAD_RADIUS * 2.0), position + Vector3(0, 0.015, 0), color.darkened(0.55))
		var ring: MeshInstance3D = lab.world_builder.ring(PAD_RADIUS, color)
		ring.position = position + Vector3(0, 0.05, 0)
		lab.world_builder.world_label("BOT PAD / %s" % ACTIONS[index], position + Vector3(0, 2.45, 0), 22, color)
		var info := Label3D.new()
		info.font_size = 15
		info.pixel_size = 0.007
		info.modulate = Color("d8e8ed")
		info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		info.position = position + Vector3(0, 2.0, 0)
		add_child(info)
		# The bot stands between the pad and the Net and faces the pad (lab convention: facing = (-sin yaw, -cos yaw)).
		var bot_spot := position + Vector3(0, 0, -BOT_DISTANCE * signf(PAD_Z))
		var toward_pad := (position - bot_spot).normalized()
		pads.append({"action": index, "position": position, "bot_spot": bot_spot, "forward": toward_pad, "yaw": atan2(-toward_pad.x, -toward_pad.z), "config": DEFAULTS.duplicate(), "actor": null, "rig": {}, "aim_marker": null, "info": info, "disc": disc, "time": 0.0, "contacted": false, "ball": null, "ball_velocity": Vector3.ZERO, "ball_state": "none", "ball_age": 0.0, "loops": 0})
		_refresh(index)

# Index of the pad the player is standing on, or -1.
func in_zone() -> int:
	for index in range(pads.size()):
		var offset: Vector3 = lab.player.position - (pads[index].position as Vector3)
		if Vector2(offset.x, offset.z).length() <= PAD_RADIUS:
			return index
	return -1

func is_spawned(index: int) -> bool:
	return is_instance_valid(pads[index].actor)

func bot_config(index: int) -> Dictionary:
	var pad: Dictionary = pads[index]
	return {"action": pad.action, "charge": pad.config.charge, "timing": pad.config.timing, "aim": pad.config.aim, "position": pad.bot_spot, "spawned": is_spawned(index)}

func interact() -> void:
	var index := in_zone()
	if index < 0:
		return
	if is_spawned(index):
		despawn(index)
	else:
		spawn(index)

func spawn(index: int) -> void:
	if is_spawned(index):
		return
	var pad: Dictionary = pads[index]
	var actor := Node3D.new()
	actor.set_meta("team", "away")
	add_child(actor)
	actor.position = pad.bot_spot
	actor.rotation.y = pad.yaw
	pad.rig = Visual.build(lab, actor, "Feli", {"palette_index": 1 + index, "marking": "none"}, lab.training_bots.physique.build)
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = pad.bot_spot
	lab.world_builder.box(pivot, Vector3(0.06, 0.02, 1.6), Vector3(0, 0.06, -0.8), COLORS[index])
	pad.actor = actor
	pad.aim_marker = pivot
	pad.loops = 0
	_refresh(index)
	_begin_loop(index)

func despawn(index: int) -> void:
	var pad: Dictionary = pads[index]
	_clear_ball(index)
	if is_instance_valid(pad.actor):
		if not pad.rig.is_empty():
			animation.states.erase(pad.rig.body.get_instance_id())
		pad.actor.get_parent().remove_child(pad.actor)
		pad.actor.queue_free()
	if is_instance_valid(pad.aim_marker):
		pad.aim_marker.get_parent().remove_child(pad.aim_marker)
		pad.aim_marker.queue_free()
	pad.actor = null
	pad.rig = {}
	pad.aim_marker = null
	pad.time = 0.0
	_refresh(index)

func despawn_all() -> void:
	for index in range(pads.size()):
		despawn(index)

func reset() -> void:
	despawn_all()
	for pad in pads:
		pad.config = DEFAULTS.duplicate()
	for index in range(pads.size()):
		_refresh(index)

func set_config(index: int, key: String, value: float) -> void:
	if not LIMITS.has(key):
		return
	var limit: Array = LIMITS[key]
	pads[index].config[key] = snappedf(clampf(value, limit[0], limit[1]), limit[2])
	_refresh(index)

func nudge(index: int, key: String, steps: int) -> void:
	set_config(index, key, float(pads[index].config[key]) + steps * float(LIMITS[key][2]))

# Seconds into the loop at which the bot makes contact.
func contact_time(index: int) -> float:
	return maxf(0.25, WINDUP + float(pads[index].config.timing))

# Where the ball is for this pad's action: the middle of the hurtbox, or its sweet region where one is defined.
func sweet_local(index: int) -> Vector3:
	var physique = lab.training_bots.physique
	var shape: Dictionary = Geometry.definition(int(pads[index].action), float(physique.build.height), physique.reach(), false, 1.0)
	var point: Vector3 = shape.center
	match str(shape.get("shape", "")):
		"sector":
			point += Geometry.sector_point(shape, 0.74, 67.5, 0.0)
		"set_sector":
			point += Vector3(0, float(shape.get("radius", 1.0)) * 0.55, 0)
	return point

func sweet_world(index: int) -> Vector3:
	var pad: Dictionary = pads[index]
	return (pad.bot_spot as Vector3) + sweet_local(index).rotated(Vector3.UP, float(pad.yaw))

# The ball leaves along the pad's facing, turned by the aim offset (the same turn the floor arrow shows).
func launch_velocity(index: int) -> Vector3:
	var pad: Dictionary = pads[index]
	var heading: Vector3 = (pad.forward as Vector3).rotated(Vector3.UP, deg_to_rad(-float(pad.config.aim)))
	var charge := float(pad.config.charge)
	return heading * (2.0 + charge * 4.0) + Vector3.UP * (4.5 + charge * 1.5)

func _begin_loop(index: int) -> void:
	var pad: Dictionary = pads[index]
	_clear_ball(index)
	pad.time = 0.0
	pad.contacted = false
	pad.loops += 1
	var ball: MeshInstance3D = lab.world_builder.sphere(self, BALL_RADIUS, sweet_world(index), COLORS[index])
	pad.ball = ball
	pad.ball_state = "held"
	pad.ball_velocity = Vector3.ZERO
	pad.ball_age = 0.0

func _clear_ball(index: int) -> void:
	var pad: Dictionary = pads[index]
	if is_instance_valid(pad.ball):
		pad.ball.get_parent().remove_child(pad.ball)
		pad.ball.queue_free()
	pad.ball = null
	pad.ball_state = "none"

func _physics_process(dt: float) -> void:
	if not is_instance_valid(lab) or lab.paused:
		return
	for index in range(pads.size()):
		if is_spawned(index):
			_tick(index, dt)

func _tick(index: int, dt: float) -> void:
	var pad: Dictionary = pads[index]
	pad.time += dt
	if pad.time >= LOOP:
		_begin_loop(index)
		pad.time = 0.0
	var strike := contact_time(index)
	var local_point := sweet_local(index)
	if not pad.contacted and pad.time >= strike:
		pad.contacted = true
		animation.contact(pad.rig, int(pad.action), local_point, "planted")
		if pad.ball_state == "held":
			pad.ball_state = "flying"
			pad.ball_velocity = launch_velocity(index)
	animation.update(pad.rig, dt, {"action": int(pad.action), "planned": not pad.contacted, "airborne": false, "remaining": maxf(0.0, strike - pad.time), "rise": 0.4, "contact_point": local_point, "posture": "planted", "speed": 0.0, "cycle": 0.0, "transition_rate": 1.0})
	if is_instance_valid(pad.ball):
		match str(pad.ball_state):
			"flying":
				var ball: MeshInstance3D = pad.ball
				ball.position += pad.ball_velocity * dt + Vector3.DOWN * (GRAVITY * dt * dt * 0.5)
				pad.ball_velocity.y -= GRAVITY * dt
				if ball.position.y <= BALL_RADIUS:
					ball.position.y = BALL_RADIUS
					pad.ball_state = "landed"
					pad.ball_age = 0.0
			"landed":
				pad.ball_age += dt
				if pad.ball_age >= LAND_LINGER:
					_clear_ball(index)

func _refresh(index: int) -> void:
	var pad: Dictionary = pads[index]
	var config: Dictionary = pad.config
	pad.info.text = "%s  /  charge %.2f  /  timing %+.2fs  /  aim %+d°\n%s" % [ACTIONS[pad.action], config.charge, config.timing, int(config.aim), "loops every %ds  /  I despawn" % int(LOOP) if is_spawned(index) else "I spawn bot"]
	if is_instance_valid(pad.aim_marker):
		(pad.aim_marker as Node3D).rotation.y = float(pad.yaw) - deg_to_rad(float(config.aim))

# Tuning keys, active only while standing on a pad: [ ] charge, ; ' timing, , . aim.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or lab.paused:
		return
	var index := in_zone()
	if index < 0:
		return
	match event.keycode:
		KEY_BRACKETLEFT: nudge(index, "charge", -1)
		KEY_BRACKETRIGHT: nudge(index, "charge", 1)
		KEY_SEMICOLON: nudge(index, "timing", -1)
		KEY_APOSTROPHE: nudge(index, "timing", 1)
		KEY_COMMA: nudge(index, "aim", -1)
		KEY_PERIOD: nudge(index, "aim", 1)
