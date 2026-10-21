extends RefCounted
## Local net response: rigid tape plus a damped webbing pocket, not a cloth solver.
const RADIUS := 0.105*1.25
const HALF_WIDTH := 4.75
const BOTTOM := 1.534
const TOP := 2.4575
const TAPE_BOTTOM := 2.4025
const HALF_DEPTH := 0.04
var origin := Vector3.ZERO
var height_offset := 0.0
var web_half_width := 4.5
var tape_half_width := HALF_WIDTH
var pocket := false
var entry_side := 1.0
var compression := 0.0
var normal_speed := 0.0
var damping := 0.0
var pocket_time := 0.0
var tape_cooldown := 0.0
var clear_side := 0.0
var last_contact := ""

func clear() -> void:
	pocket = false
	compression = 0.0
	normal_speed = 0.0
	pocket_time = 0.0
	tape_cooldown = 0.0
	clear_side = 0.0
	last_contact = ""

static func tape_velocity(velocity: Vector3,normal: Vector3,tangent_retention: float = 0.82,normal_retention: float = 0.22) -> Vector3:
	var approach := velocity.dot(normal)
	return velocity if approach >= 0 else (velocity-normal*approach)*tangent_retention-normal*approach*normal_retention

static func slab_hit(from: Vector3,to: Vector3,minimum: Vector3,maximum: Vector3) -> float:
	var lo := 0.0
	var hi := 1.0
	var travel := to-from
	for axis in range(3):
		if absf(travel[axis]) < 0.000001:
			if from[axis] < minimum[axis] or from[axis] > maximum[axis]: return -1.0
		else:
			var a: float = (minimum[axis]-from[axis])/travel[axis]
			var b: float = (maximum[axis]-from[axis])/travel[axis]
			lo = maxf(lo,minf(a,b))
			hi = minf(hi,maxf(a,b))
			if lo > hi: return -1.0
	return lo

func step(previous: Vector3,position: Vector3,velocity: Vector3,dt: float,charge: float) -> Dictionary:
	var offset := origin+Vector3.UP*height_offset
	var result := _step_local(previous-offset,position-offset,velocity,dt,charge)
	result.position += offset
	result["pocket"] = pocket
	result["net_origin"] = origin
	result["net_bottom"] = BOTTOM+height_offset
	result["net_half_width"] = web_half_width
	return result

func touches_body(from: Vector3,to: Vector3,height: float = 1.7,radius: float = MIDLINE_RADIUS) -> bool:
	var offset := origin+Vector3.UP*height_offset
	return body_touches(from-offset,to-offset,radius,height,web_half_width,tape_half_width)

func _step_local(previous: Vector3,position: Vector3,velocity: Vector3,dt: float,charge: float) -> Dictionary:
	var result := {"position":position,"velocity":velocity,"contact":"","crossed":false}
	if clear_side == 0 and absf(previous.z) > HALF_DEPTH+RADIUS:
		clear_side = signf(previous.z)
	tape_cooldown = maxf(0,tape_cooldown-dt)
	if pocket:
		advance_pocket(result,dt)
	else:
		var tape := slab_hit(previous,position,Vector3(-tape_half_width-RADIUS,TAPE_BOTTOM-RADIUS,-HALF_DEPTH-RADIUS),Vector3(tape_half_width+RADIUS,TOP+RADIUS,HALF_DEPTH+RADIUS)) if tape_cooldown <= 0 else -1.0
		var web := slab_hit(previous,position,Vector3(-web_half_width-RADIUS,BOTTOM-RADIUS,-HALF_DEPTH-RADIUS),Vector3(web_half_width+RADIUS,TAPE_BOTTOM+RADIUS,HALF_DEPTH+RADIUS))
		if tape >= 0 and (web < 0 or tape <= web+0.00001):
			var point := previous.lerp(position,tape)
			var nearest := Vector3(clampf(point.x,-tape_half_width,tape_half_width),clampf(point.y,TAPE_BOTTOM,TOP),clampf(point.z,-HALF_DEPTH,HALF_DEPTH))
			var normal := (point-nearest).normalized()
			if normal.length_squared() < 0.01:
				normal = Vector3(0,0,signf(previous.z) if previous.z != 0 else -signf(velocity.z))
			var approach := velocity.dot(normal)
			if approach < 0:
				result.velocity = tape_velocity(velocity,normal,0.55,0.10)
				result.position = nearest+normal*(RADIUS+0.002)+Vector3(result.velocity)*dt*(1.0-tape)
				result.contact = "tape"
				tape_cooldown = 0.045
		elif web >= 0:
			entry_side = signf(previous.z) if previous.z != 0 else -signf(velocity.z)
			if entry_side == 0: entry_side = 1.0
			normal_speed = maxf(0,-velocity.z*entry_side)
			var pressure := clampf(normal_speed/25.0+maxf(charge,0)*0.25,0,1)
			damping = lerpf(38.0,14.0,pressure)
			compression = 0.0
			pocket_time = 0.0
			pocket = true
			result.velocity = Vector3(velocity.x*0.55,velocity.y*0.45,velocity.z)
			result.position = previous.lerp(position,web)
			advance_pocket(result,dt*(1.0-web))
			result.contact = "webbing"
	last_contact = str(result.contact)
	# A temporary excursion inside stretched webbing is not a court crossing.
	var resolved: Vector3 = result.position
	if not pocket and absf(resolved.z) > HALF_DEPTH+RADIUS+0.001:
		var side := signf(resolved.z)
		result.crossed = clear_side != 0 and side != clear_side
		clear_side = side
	return result

func advance_pocket(result: Dictionary,dt: float) -> void:
	pocket_time += dt
	# Small substeps keep the spring stable even on a low frame rate.
	var remaining := dt
	while remaining > 0:
		var step_dt := minf(remaining,1.0/240)
		normal_speed += (-100.0*compression-damping*normal_speed)*step_dt
		compression += normal_speed*step_dt
		remaining -= step_dt
	var position: Vector3 = result.position
	var velocity: Vector3 = result.velocity
	position.z = entry_side*(HALF_DEPTH+RADIUS-compression)
	velocity.z = -entry_side*normal_speed
	velocity.x *= exp(-4.0*dt)
	result.contact = "webbing"
	if compression <= 0 and normal_speed < 0:
		pocket = false
		position.z = entry_side*(HALF_DEPTH+RADIUS+0.003)
	elif pocket_time >= 0.45 or position.y < BOTTOM-RADIUS or absf(position.x) > web_half_width+RADIUS:
		pocket = false
		position.z = entry_side*(HALF_DEPTH+RADIUS+0.003)
		velocity.z = entry_side*minf(absf(normal_speed)*0.2,0.8)
	result.position = position
	result.velocity = velocity

# A player faults only when the vertical midline of their body touches the net: a shoulder or an arm brushing it does not count.
const MIDLINE_RADIUS := 0.02

static func body_touches(from: Vector3,to: Vector3,radius: float = MIDLINE_RADIUS,height: float = 1.7,web_width: float = 4.5,tape_width: float = HALF_WIDTH) -> bool:
	# Sweep the vertical body capsule against the actual net band, including edges.
	var t := clampf(-from.z/(to.z-from.z),0,1) if absf(to.z-from.z) > 0.000001 else 0.0
	for position in [from,to,from.lerp(to,t)]:
		var low: float = position.y+radius
		var high: float = position.y+height-radius
		for band in [[web_width,BOTTOM,TAPE_BOTTOM],[tape_width,TAPE_BOTTOM,TOP]]:
			var dx := maxf(absf(position.x)-float(band[0]),0)
			var dy := maxf(maxf(float(band[1])-high,low-float(band[2])),0)
			var dz := maxf(absf(position.z)-HALF_DEPTH,0)
			if Vector3(dx,dy,dz).length() <= radius+0.003: return true
	return false
