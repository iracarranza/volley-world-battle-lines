extends RefCounted
const ContactResolver := preload("res://scripts/contact/contact_resolver.gd")
const ReceiveOutcome := preload("res://scripts/receive_outcome.gd")
const Geometry := preload("res://scripts/contact_geometry.gd")
const Execution := preload("res://scripts/contact_execution.gd")
const Influence := preload("res://scripts/directional_influence.gd")
const Spike := preload("res://scripts/spike_direction.gd")
const NEAR_METERS := 3.5
const FLIGHT_FRACTION := 0.35
const MAX_SECONDS := 0.70
const MAX_LENGTH := 5.5
const SAMPLES := 36

# The hint assumes ideal timing and a matching receive charge. It retains the
# current platform/arm intersection, stats and DI; it never changes live state.
static func predict(lab: Node3D) -> Dictionary:
	if lab.moc.steering_active() and lab.ball_active:
		var live := flight(lab.ball.position,lab.ball_velocity,lab.GRAVITY)
		live.merge({"contact_ready":true,"action":lab.moc.steering.action,"steering":true,"color":lab.moc.steering_feedback.get("color",Color("59d8ff")),"hp_cost":lab.moc.steering.spent})
		live.make_read_only()
		return live
	if lab.is_benched() or not lab.ball_active or not (lab.armed or lab.charging) or lab.serve.tossing():
		return {}
	var action: int = lab.locked_action if lab.armed else (lab.motion.airborne_action if lab.motion.jumped and lab.motion.airborne_action >= 0 else lab.selected)
	var origin: Vector3 = lab.ball.position
	var nearby: Vector3 = lab.player.position + Vector3.UP * float(lab.athlete.build.height) * 0.8
	if origin.distance_to(nearby) > NEAR_METERS:
		return {}
	var yaw: float = lab._contact_yaw()
	var local: Vector3 = (origin-lab.player.position).rotated(Vector3.UP,-yaw)
	if action == 0 and local.z > 0:
		return {} # A receiving platform cannot reach behind the athlete.
	var shape: Dictionary = lab._hurtbox_definition(action)
	var reachable := Geometry.contains(shape,local)
	var sample := local if reachable else projected_contact(shape,local,action)
	var spatial := Geometry.evaluate(shape,sample)
	if not spatial.hit:
		return {}
	var request = lab.contact_request(action)
	request.local_point = sample
	request.confirmation_age = Execution.SWEET_DELAY
	request.remembered = false
	request.ideal_charge_match = true
	request.apply_set_spread = false
	request.apply_block_spread = false
	var power: float = lab.prepared_output_charge() if lab.armed else lab.charge
	var target: Vector3 = lab.committed_intent.get("target", lab.aim)
	request.charge = power
	request.intent_direction = target - origin
	request.base_velocity = lab._shot_velocity(origin, action, power, target)
	var assessment := ContactResolver.assess(request)
	var velocity := ContactResolver.resolve(request, assessment).velocity
	var result := flight(origin,velocity,lab.GRAVITY)
	result.merge({"contact_ready":reachable,"action":action,"assessment":assessment,"charge":power,"ideal_timing":true,"ideal_charge_match":true})
	result.make_read_only()
	return result

static func flight(origin: Vector3,velocity: Vector3,gravity: float) -> Dictionary:
	var drop := maxf(origin.y-Geometry.VISUAL_BALL_RADIUS,0)
	var full_time := (velocity.y+sqrt(velocity.y*velocity.y+2*gravity*drop))/gravity
	var duration := minf(full_time*FLIGHT_FRACTION,MAX_SECONDS)
	var drawn_duration := duration
	var points: Array[Vector3] = [origin]
	var length := 0.0
	for index in range(1,SAMPLES+1):
		var t := duration*float(index)/SAMPLES
		var point := origin+velocity*t+Vector3.DOWN*gravity*t*t*0.5
		var segment := points[-1].distance_to(point)
		if length+segment > MAX_LENGTH:
			var fraction := (MAX_LENGTH-length)/maxf(segment,0.000001)
			drawn_duration = duration*(index-1+fraction)/SAMPLES
			points.append(points[-1].lerp(point,fraction))
			break
		points.append(point)
		length += segment
	return {"origin":origin,"velocity":velocity,"points":points,"duration":drawn_duration,"full_flight_time":full_time}

static func projected_contact(shape: Dictionary, local: Vector3, action: int) -> Vector3:
	if shape.has("base_geometry"):
		var base_point := projected_contact(shape.base_geometry,Geometry.unscaled_point(shape,local),action)
		var pivot: Vector3 = shape.geometry_pivot
		return pivot+(base_point-pivot)*Vector3(shape.geometry_scale)
	var center: Vector3 = shape.center
	var point := local-center
	match action:
		0:
			var x := local.x/float(shape.side_reach)
			var front := maxf(0.02,-local.z/float(shape.forward_reach))
			var footprint := Vector2(x,front).limit_length(0.94)
			return Vector3(footprint.x*float(shape.side_reach),clampf(local.y,center.y-float(shape.size.y)*0.45,center.y+float(shape.size.y)*0.45),-footprint.y*float(shape.forward_reach))
		1:
			point.y = clampf(point.y,float(shape.min_y)+0.02,float(shape.radius)*0.94)
			var radius := Geometry.SetHurtbox.outer_radius(shape,point.y)*0.94
			var horizontal := Vector2(point.x,point.z).limit_length(radius)
			return center+Vector3(horizontal.x,point.y,horizontal.y)
		2:
			var radial := Vector2(point.x,maxf(0.03,point.y)).limit_length(float(shape.radius)*0.94)
			return center+Vector3(radial.x,radial.y,clampf(point.z,-float(shape.depth)*0.44,float(shape.depth)*0.44))
		3:
			var y := clampf(local.y,float(shape.bottom)+0.02,float(shape.top)-0.02)
			var width := Geometry.BlockField.width(shape,y)*0.94
			return Vector3(clampf(local.x,-width,width),y,clampf(local.z,center.z-float(shape.size.z)*0.44,center.z+float(shape.size.z)*0.44))
	return center

static func ribbon(result: Dictionary, camera: Vector3, mesh: ImmediateMesh = null) -> ImmediateMesh:
	if mesh == null:
		mesh = ImmediateMesh.new()
	mesh.clear_surfaces()
	if result.is_empty():
		return mesh
	var points: Array = result.points
	if points.size() < 2:
		return mesh
	var readiness := 1.0 if result.contact_ready else 0.65
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size()-1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index+1]
		var tangent := (b-a).normalized()
		var side := tangent.cross(camera-(a+b)*0.5).normalized()
		if side.length_squared() < 0.001:
			side = tangent.cross(Vector3.UP).normalized()
		var progress := float(index)/(points.size()-1)
		var end_progress := float(index+1)/(points.size()-1)
		for glow in [true,false]:
			var half_width := 0.11 if glow else 0.023
			var alpha := (0.50 if glow else 1.0)*readiness
			var tint: Color = result.get("color",Color("59d8ff"))
			var color := tint if glow else tint.lerp(Color.WHITE,0.18)
			var fade_a := (1.0-smoothstep(0.80,1,progress))*alpha
			var fade_b := (1.0-smoothstep(0.80,1,end_progress))*alpha
			var offset_a := side*half_width*lerpf(1,0.55,progress)
			var offset_b := side*half_width*lerpf(1,0.55,end_progress)
			var corners := [a-offset_a,a+offset_a,b+offset_b,b-offset_b]
			for corner in [0,1,2,0,2,3]:
				mesh.surface_set_color(Color(color,fade_a if corner < 2 else fade_b))
				mesh.surface_add_vertex(corners[corner])
		if index % 7 == 3 and progress < 0.8:
			var color: Color = Color(result.get("color",Color("59d8ff"))).lerp(Color.WHITE,0.10)
			color.a = 1.0*readiness*(1-progress)
			for point in [a+tangent*0.14,a-tangent*0.06+side*0.12,a-tangent*0.06-side*0.12]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh
