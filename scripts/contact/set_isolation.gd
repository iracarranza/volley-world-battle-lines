extends RefCounted
## A set separates incoming handling effort from intended outgoing power.
const COMFORT_PRESSURE := 0.20
const HANDLING_GAIN := 1.25

static func pressure(shot: Dictionary,velocity: Vector3) -> float:
	return maxf(maxf(0,float(shot.get("charge",0))),pow(velocity.length()/30.0,2)*0.65)

static func effort(pressure_value: float) -> float:
	return maxf(0,(pressure_value-COMFORT_PRESSURE)/HANDLING_GAIN)

static func assess(request: RefCounted,assessment: Dictionary) -> Dictionary:
	var incoming_pressure := pressure(request.incoming_shot,request.incoming)
	var handling: float = request.handling_charge if request.auto_charge else request.charge
	var geometry := clampf(float(assessment.get("quality",0.35)),0,1)
	var capacity: float = COMFORT_PRESSURE+maxf(0,handling)*request.athlete.low_stamina_factor()*HANDLING_GAIN*(0.65+0.35*geometry)
	var overload := maxf(0,incoming_pressure-capacity)
	var severity := smoothstep(0,0.65,overload)
	return {"pressure":incoming_pressure,"handling_charge":handling,"capacity":capacity,"overload":overload,"severity":severity,"output_charge":request.charge}

static func velocity(incoming: Vector3,intended: Vector3,isolation: Dictionary,facing: Vector3) -> Vector3:
	var severity := float(isolation.severity)
	if severity <= 0: return intended
	# Overwhelmed hands lose isolation: residual pace leaks sideways/upward.
	var normal := (facing+Vector3.UP*0.6).normalized()
	if incoming.dot(normal) > 0: normal = -normal
	var residual := incoming.bounce(normal)*0.45
	residual.y = maxf(0.1,residual.y)
	return intended.lerp(residual,severity*0.85)
