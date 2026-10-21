extends "res://tests/support/test_case.gd"
const Request := preload("res://scripts/contact/contact_request.gd")
const Resolver := preload("res://scripts/contact/contact_resolver.gd")
const Response := preload("res://scripts/contact/block_response.gd")
const Field := preload("res://scripts/block_field.gd")
const Athlete := preload("res://scripts/athlete.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var req := Request.new()
	req.action = 3
	req.athlete = Athlete.new()
	req.shape = Field.definition(1.86,req.athlete.reach())
	req.facing = Vector3.FORWARD
	req.block_confirmation_age = 0
	req.incoming = Vector3(0,-6,25)
	var shape: Dictionary = req.shape
	var low: float = shape.bottom+0.3
	for point in [Vector3(shape.hand_x,shape.palm,shape.center.z),Vector3(Field.width(shape,low),low,shape.center.z),Vector3(0,shape.top-0.01,shape.center.z)]:
		req.local_point = point
		var speeds := []
		for charge in [0.02,0.6,1.2,2.0]:
			req.incoming_shot = {"kind":"attack","charge":charge}
			var result := Response.resolve(req,Resolver.assess(req))
			var ratio: float = result.velocity.length()/req.incoming.length()
			check(result.velocity.is_finite() and ratio <= 0.48001,"Block never adds speed and retains at most 48 percent")
			check(is_equal_approx(result.evidence.speed_retention,ratio),"Absorption evidence describes actual output")
			speeds.append(ratio)
		check(speeds[0] < 0.15,"Matched touch primarily absorbs momentum at each region")
		check(speeds[-1] > speeds[0]*2,"Large mismatch releases more deflection pace")
		check(speeds[1] >= speeds[0] and speeds[2] >= speeds[1] and speeds[3] >= speeds[2],"Mismatch produces a graduated deflection spectrum")
	req.incoming = Vector3.ZERO
	req.incoming_shot = {"charge":0}
	check(Response.resolve(req,Resolver.assess(req)).velocity == Vector3.ZERO,"A stationary ball does not acquire artificial rebound speed")
	print("CONTACT ABSORPTION: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
