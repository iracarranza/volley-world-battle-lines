extends RefCounted
const Stats := preload("res://scripts/stat_tuning.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const Snapshot := preload("res://scripts/contact/snapshot.gd")
const PRESS_SECONDS := 0.5
static func assess(request: RefCounted,spatial: Dictionary) -> Dictionary:
	var result := spatial.duplicate(true)
	var age: float = request.block_confirmation_age
	var pulse := pow(clampf(1.0-age/PRESS_SECONDS,0,1),3) if age >= 0 else 0.0
	var reference: float = Stats.reaction_cap(request.athlete.stat("reaction_speed"))*request.athlete.low_stamina_factor()
	var effort: float = reference if request.block_charge_reference < 0 else request.block_charge_reference*request.athlete.low_stamina_factor()
	var passive := reference*0.75
	var press := effort*0.75*(1.0+float(spatial.get("block_sweet_weight",1)))
	var capacity: float = lerpf(passive,press,pulse)*float(spatial.get("block_capacity",1))
	var incoming_charge := maxf(0,float(request.incoming_shot.get("charge",request.incoming.length()/30.0)))
	var tolerance: float = request.athlete.trait_effect("charge_tolerance")
	var severity := smoothstep(0,maxf(0.05,0.35*(1.0+tolerance/100.0)),maxf(0,incoming_charge-capacity))
	result["sweet"] = bool(result.hit) and pulse > 0.05 and float(spatial.get("block_sweet_weight",0)) > 0.75 and severity < 0.05
	result["rescue"] = false
	result["confirmation_age"] = age
	result["block_response"] = {"capacity":capacity,"auto_reference":reference,"regional_factor":spatial.get("block_capacity",1),"confirmation_pulse":pulse,"incoming_charge":incoming_charge,"severity":severity,"region":spatial.get("block_region","CORE"),"height":spatial.get("block_height",0.8),"side":spatial.get("block_side",0),"sweet_weight":spatial.get("block_sweet_weight",1)}
	result["charge_match"] = {"matched":severity <= 0.00001,"status":"undercharged" if severity > 0 else "matched","severity":severity,"incoming_charge":incoming_charge,"receive_charge":capacity,"minimum":incoming_charge,"maximum":INF}
	return result

static func resolve(request: RefCounted,assessment: Dictionary) -> Dictionary:
	var response: Dictionary = assessment.block_response.duplicate(true)
	var facing: Vector3 = request.facing.normalized()
	var yaw := atan2(-facing.x,-facing.z)
	var incoming: Vector3 = request.incoming.rotated(Vector3.UP,-yaw)
	var height := float(response.height)
	var side := float(response.side)
	var edge := 1.0-float(response.regional_factor)
	var severity := float(response.severity)
	var timing := clampf(request.athlete.timing()/100.0,0,1)
	var lift := lerpf(0.10,0.92,height)*edge
	var normal := Vector3(side*(0.15+edge*0.9),lift,-maxf(0.05,1.0-height*edge*1.45)).normalized()
	if incoming.dot(normal) > 0: normal = -normal
	var reflected := incoming.bounce(normal)
	var pace := incoming.length()
	var flow := clampf(request.flow/100.0,0,1)
	# Capacity absorbs pace first; geometry and DI still select where the touch goes.
	# Mismatch progressively releases more incoming energy into the deflection.
	var retention := lerpf(0.12,0.48,severity)*(1.0-edge*0.4)*(1.0-0.15*flow)
	var controlled := Vector3(side*edge*0.20,-(0.18+0.30*timing*float(response.sweet_weight)),-1.0)
	controlled.y += incoming.y/maxf(pace,1)*0.25-0.08*flow
	controlled = controlled.normalized()*pace*retention
	var escape := reflected.normalized()*pace*retention
	var upper := smoothstep(0.62,0.94,height)*smoothstep(0.08,0.55,edge)
	var soft_back := Vector3(side*0.55,maxf(0.25,-incoming.y/maxf(pace,1)*0.5),0.65).normalized()*pace*retention
	escape = escape.lerp(soft_back,upper*(0.65+0.20*severity))
	if escape.length_squared() > 0.001:
		escape = (escape.normalized()+Vector3(side*edge*0.35,0,0)).normalized()*escape.length()
	var mix := clampf(edge*0.65+severity*0.60+upper*0.45,0,1)
	var outgoing := controlled.lerp(escape,mix)
	response["retention"] = retention
	response["outcome"] = "soft_backward" if outgoing.z > 0 and severity < 0.5 else ("overpowered_touch" if severity >= 0.5 else ("soft_outward" if absf(side) > 0.5 else "controlled_return"))
	var scatter: float = (signf(side) if absf(side) > 0.02 else (signf(incoming.x) if absf(incoming.x) > 0.02 else 1.0))*0.64*edge*(0.04+0.14*severity)/(1.0+request.athlete.ball_control()/100.0)
	outgoing = outgoing.rotated(Vector3.UP,scatter)
	response["speed_retention"] = outgoing.length()/maxf(pace,0.001)
	response["absorbed_speed_fraction"] = 1.0-float(response.speed_retention)
	var world := outgoing.rotated(Vector3.UP,yaw)
	var point: Vector3 = request.local_point
	var shape: Dictionary = request.shape
	# Separate beyond the face in the actual departure direction, including roofs.
	var horizontal := Vector3(outgoing.x,0,outgoing.z)
	var departure := horizontal.normalized() if horizontal.length_squared() > 0.01 else normal
	var sign_z := signf(departure.z)
	var target_z := float(shape.center.z)+sign_z*(float(shape.size.z)*0.5+Geometry.BALL_RADIUS+0.02)
	var offset := Vector3(0,0,target_z-point.z).rotated(Vector3.UP,yaw)
	var charge := maxf(0,float(response.incoming_charge)*pow(world.length()/maxf(request.incoming.length(),18),2))
	return {"evidence":response,"velocity":world,"separation_offset":offset,"shot":Snapshot.freeze({"kind":"block","actor":request.actor_id,"charge":charge,"action_charge":request.charge,"delivery_quality":assessment.quality,"reference_speed":world.length(),"block_response":response})}
