extends RefCounted
## Real-time steering of a contacted ball. Physical flight still uses its local clock.
const Influence := preload("res://scripts/directional_influence.gd")
const BLUE := Color("59d8ff")
const RED := Color("ff5969")
var axes := Vector3.ZERO
var base := Vector3.ZERO
var facing := Vector3.FORWARD
var quality := 1.0
var action := 2
var vision := 0.0
var spent := 0.0
var velocity := Vector3.ZERO
var geometry := 0.0

func begin(event: Dictionary, court_vision: float) -> void:
	axes = Vector3.ZERO
	spent = 0.0
	base = event.get("outgoing_velocity",Vector3.ZERO)
	velocity = base
	var info: Dictionary = event.get("steering",{})
	facing = info.get("facing",event.get("intent",{}).get("direction",Vector3.FORWARD))
	facing = Vector3(facing.x,0,facing.z).normalized()
	if facing.length_squared() < 0.001: facing = Vector3.FORWARD
	quality = float(event.get("quality",1))
	action = int(event.get("action",2))
	vision = court_vision
	geometry = float(info.get("lateral_offset",0))

func step(input: Vector3, dt: float, rate: float, hp_per_unit: float, available_hp: float) -> Dictionary:
	input.y = 0
	var next := (axes+input.limit_length(1)*maxf(0,dt)*maxf(0,rate)).limit_length(1)
	var change := next-axes
	var cost := change.length()*maxf(0,hp_per_unit)
	if cost > available_hp and cost > 0:
		change *= maxf(0,available_hp)/cost
		cost = maxf(0,available_hp)
	axes += change
	spent += cost
	var result := Influence.resolve(base,2 if action == 3 else action,axes,facing,quality,vision)
	velocity = result.velocity
	if action == 2:
		var agreement := signf(geometry)*float(result.axes.x)
		if agreement < 0:
			var initial_yaw := atan2(-base.x,-base.z)
			var facing_yaw := atan2(-facing.x,-facing.z)
			var bias := wrapf(initial_yaw-facing_yaw,-PI,PI)
			var outgoing_yaw := wrapf(atan2(-velocity.x,-velocity.z)-facing_yaw,-PI,PI)
			var corrected := clampf(outgoing_yaw,minf(0,bias),maxf(0,bias))
			velocity = facing.rotated(Vector3.UP,corrected)*Vector2(velocity.x,velocity.z).length()+Vector3.UP*velocity.y
		velocity *= 1.0+agreement*clampf(absf(geometry)/0.70,0,1)*(0.18 if agreement >= 0 else 0.22)
	return {"velocity":velocity,"cost":cost,"amount":axes.length(),"spent":spent,"color":BLUE.lerp(RED,axes.length())}
