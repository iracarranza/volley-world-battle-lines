extends "res://tests/support/test_case.gd"
const Request := preload("res://scripts/contact/contact_request.gd")
const Resolver := preload("res://scripts/contact/contact_resolver.gd")
const Response := preload("res://scripts/contact/receive_response.gd")
const Registry := preload("res://scripts/contact/mechanic_registry.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Platform := preload("res://scripts/receive_platform.gd")
const Charge := preload("res://scripts/receive_charge.gd")
const Store := preload("res://scripts/athlete_store.gd")

func sample(height: float, side: float, speed: float, charge: float, age: float, seed_value: int = 7) -> RefCounted:
	var request := Request.new()
	request.athlete = Athlete.new()
	request.shape = Platform.definition(1.86, false)
	request.local_point = Vector3(side * request.shape.side_reach, request.shape.center.y + (height - 0.5) * request.shape.size.y, -0.65)
	request.origin = request.local_point
	request.incoming = Vector3(0, -speed * 0.15, speed)
	request.incoming_shot = Charge.shot("serve", 0.75, "drill")
	request.charge = charge
	request.confirmation_age = age
	request.base_velocity = Vector3(0, 7, -8)
	request.response_seed = seed_value
	return request

func resolve(request: RefCounted) -> RefCounted:
	return Resolver.resolve(request, Resolver.assess(request))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for speed in [3.0, 12.0, 24.0, 36.0]:
		for height in [0.02, 0.3, 0.55, 0.95]:
			for side in [-0.75, 0.0, 0.75]:
				for age in [0.02, 0.22, 0.52]:
					for charge in [0.0, 0.35, 0.74, 0.82, 1.0]:
						var request := sample(height, side, speed, charge, age)
						var result := resolve(request)
						check(result.velocity.is_finite() and result.separation_offset.is_finite(), "Response remains finite")
						check(result.velocity.length() < maxf(20, request.incoming.length() * 1.6), "Weak contacts do not invent unbounded shot energy")
						var start: Vector3 = request.local_point + result.separation_offset
						var radius := 1.86 * 0.22 + Response.BALL_RADIUS
						for step in range(1, 13):
							var time := float(step) * 0.01
							var p: Vector3 = start + result.velocity * time + Vector3.DOWN * request.gravity * time * time * 0.5
							var inside := Vector2(p.x, p.z).length() < radius - 0.001 and p.y > 0 and p.y < 1.86 * 1.05 + Response.BALL_RADIUS
							check(not inside, "Confirmed receive departs without crossing the athlete")
	for incoming in [Vector3(12, -5, 20), Vector3(-12, -5, 20), Vector3(0, 8, 16), Vector3(0, 6, -3), Vector3(20, -2, 0)]:
		for h in [0.1, 0.6, 0.95]:
			for side in [-0.7, 0.0, 0.7]:
				var request := sample(h, side, 20, 0.0, 0.02)
				request.incoming = incoming
				var result := resolve(request)
				var normal: Vector3 = result.assessment.receive_response.effective_normal
				check(result.velocity.dot(normal) >= -0.0001, "Oblique/rising contacts separate from their effective platform: %s / %.2f / %.2f" % [incoming, h, side])
	var still := sample(0.5, 0, 0, 0.82, 0.22)
	check(resolve(still).outgoing_shot.charge < 1.0, "A stopped ball cannot amplify stale incoming charge metadata")
	var low := resolve(sample(0.02, 0, 3, 0, 0.52))
	check(low.velocity.y < 0.5 and low.velocity.length() < 1, "Very weak slow early bottom contact dies near the floor")
	var fast_low := resolve(sample(0.02, 0, 24, 0, 0.52))
	check(fast_low.velocity.y < 0.6, "Early bottom contact remains low against a fast ball")
	var left := resolve(sample(0.7, -0.75, 24, 0.1, 0.02))
	var right := resolve(sample(0.7, 0.75, 24, 0.1, 0.02))
	check(absf(left.velocity.x + right.velocity.x) < 0.0001 and absf(left.velocity.z - right.velocity.z) < 0.0001, "Mirrored intersections produce mirrored responses with the same seed")
	var early := resolve(sample(0.6, 0.7, 24, 0.1, 0.52))
	var late := resolve(sample(0.6, 0.7, 24, 0.1, 0.02))
	check(early.assessment.receive_response.early > 0.9 and late.assessment.receive_response.late > 0.9, "Preparation labels follow input lead rather than reversing early and late")
	check(early.velocity.distance_to(late.velocity) > 0.2, "Early and late preparation have different mechanical failures")
	var a := sample(0.8, 0.65, 24, 0.1, 0.02)
	var result := resolve(a)
	check(resolve(a).velocity == result.velocity, "Same contact seed is reproducible")
	a.response_seed = 31
	check(resolve(a).velocity.distance_to(result.velocity) > 0.05, "Different seeds give bounded contact variation")
	var matched := resolve(sample(0.5, 0, 24, 0.82, 0.22))
	check(matched.outgoing_shot.charge != matched.outgoing_shot.action_charge and matched.outgoing_shot.delivery_quality > 0.5, "Clean receive conditions ball pressure rather than copying the input")
	check(matched.mechanics.size() == Registry.STAGES.size() and matched.mechanics.is_read_only(), "All contacts publish the ordered named mechanic trace")
	check(matched.mechanics[0].id == "geometry" and matched.mechanics[-1].id == "consequences", "Trace follows the declared sequence")
	var clean_but_under := resolve(sample(0.5, 0, 24, 0.1, 0.22))
	check(clean_but_under.mechanics[0].evidence.zone == "CLEAN" and clean_but_under.mechanics[1].evidence.sweet_eligible and not clean_but_under.assessment.sweet, "Trace preserves good geometry/timing separately from the failed charge match")
	# Real tree effects alter only their named layers, without granting a match.
	var book = Store.trait_book()
	book.nodes.append({"id": "test_receive", "name": "Any display name", "effects": {"receive_control": 35, "receive_absorption": 25, "receive_redirection": 25}})
	var baseline_request := sample(0.65, 0.7, 24, 0.35, 0.02)
	var baseline := resolve(baseline_request)
	baseline_request.athlete.trait_ids.assign(["test_receive"])
	var improved := resolve(baseline_request)
	check(improved.assessment.charge_match.status == baseline.assessment.charge_match.status and not improved.assessment.sweet, "Trait control cannot manufacture matching or sweetness")
	check(improved.assessment.receive_response.uncontrolled_fraction < baseline.assessment.receive_response.uncontrolled_fraction, "Receive Control improves conditioning through the actual trait book")
	check(improved.assessment.receive_response.retention < baseline.assessment.receive_response.retention, "Receive Absorption damps retained pace")
	check(absf(improved.assessment.receive_response.scatter_radians) < absf(baseline.assessment.receive_response.scatter_radians), "Receive Redirection reduces scatter")
	book.nodes.pop_back()
	print("RECEIVE RESPONSE: %d / %d" % [checks - failures, checks])
	quit(1 if failures else 0)
