extends SceneTree
const Outcome := preload("res://scripts/receive_outcome.gd")
const Platform := preload("res://scripts/receive_platform.gd")
const Charge := preload("res://scripts/receive_charge.gd")
const Execution := preload("res://scripts/contact_execution.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func sample(point: Vector3, charge: float = 0.65, incoming_charge: float = 0.65, input: Vector3 = Vector3.ZERO, speed: float = 0, yaw: float = 0) -> Dictionary:
	var shape := Platform.definition(1.86,false)
	var spatial := Platform.evaluate(shape,point-Vector3(shape.center))
	var assessment := Charge.assess(Execution.assess(spatial,0.22,false,0),Charge.shot("attack",incoming_charge,"test"),charge)
	return Outcome.assess(assessment,shape,point,speed,input.rotated(Vector3.UP,yaw),yaw)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var center := Vector3(0,0.95,-0.55)
	var low := Vector3(0,0.4,-0.55)
	var right := Vector3(0.75,0.95,-0.4)
	var reach := Vector3(0.2,0.95,-1.45)
	check(sample(low).recovery == "knee","Bottom third selects Knee")
	check(sample(center).recovery == "","Central good receive has no forced recovery")
	check(sample(center,0.1,0.8).recovery == "blown_away","Central severe undercharge selects Blown Away")
	check(sample(low,0.1,0.8).recovery == "blown_away","Underpowered shank takes priority over Knee")
	check(sample(right,0.1,0.8).recovery == "fall_roll","Off-axis severe undercharge selects Fall Roll")
	check(sample(Vector3(-right.x,right.y,right.z),0.1,0.8).recovery == "fall_roll","Fall classification is symmetric")
	check(sample(reach,0.1,0.8).recovery == "fall_slide","Reaching severe undercharge selects Fall Slide")
	check(sample(Vector3(0.52,0.95,-1.2),0.1,0.8,Vector3.ZERO,2).recovery == "fall_slide","Moving off-center undercharge selects Fall Slide")
	check(sample(center,0.6,0.65,Vector3.BACK).recovery == "shrug","Backward influence turns a mild central deficit into Shrug")
	check(sample(center,0.6,0.65).recovery != "shrug","Neutral mild deficit does not force Shrug")
	var low_mild := sample(low,0.6,0.65,Vector3.FORWARD)
	check(low_mild.recovery == "knee" and low_mild.receive_outcome.penalty_factor < 1,"Forward input still helps Knee with a mild charge deficit")
	check(sample(low,0.6,0.65,Vector3.BACK).recovery == "shrug","Backward input can turn mild low central deficit into Shrug")
	check(sample(center,1,0.3).recovery != "blown_away","Overcharge does not select an underpowered outcome")
	for fixture in [{"point":right,"input":Vector3.RIGHT},{"point":Vector3(-right.x,right.y,right.z),"input":Vector3.LEFT},{"point":reach,"input":Vector3.RIGHT},{"point":low,"input":Vector3.FORWARD},{"point":center,"input":Vector3.BACK}]:
		var point: Vector3 = fixture.point
		var input: Vector3 = fixture.input
		var charge := 0.1 if point == center else 0.65
		var required := 0.8 if point == center else 0.65
		var neutral := sample(point,charge,required)
		var good := sample(point,charge,required,input)
		var wrong := sample(point,charge,required,-input)
		check(good.receive_outcome.penalty_factor < neutral.receive_outcome.penalty_factor,"Correct DI mitigates relevant penalty")
		check(wrong.receive_outcome.penalty_factor > neutral.receive_outcome.penalty_factor,"Contrary DI worsens relevant penalty")
		check(good.quality >= neutral.quality and wrong.quality <= neutral.quality,"Quality follows correction")
		var rotated := sample(point,charge,required,input,0,1.2)
		check(is_equal_approx(rotated.receive_outcome.di_alignment,good.receive_outcome.di_alignment),"DI correction follows athlete facing")
	var helped := sample(center,0.1,0.8,Vector3.BACK)
	check(not helped.sweet and not helped.charge_match.matched,"DI cannot erase mismatch or grant sweet contact")
	check(helped.charge_match.severity < helped.charge_match.raw_severity,"Backward DI reduces undercharge shank severity")
	check(sample(center,0.649,0.65).receive_outcome.charge_severity < 0.001,"Near misses remain gradual")
	check(Outcome.velocity(Vector3(0,8,-5),sample(low,0.65,0.65,Vector3.FORWARD)).y > Outcome.velocity(Vector3(0,8,-5),sample(low)).y,"Forward DI recovers Knee lift")
	for height in [1.5,1.86,2.2]:
		var shape := Platform.definition(height,false)
		var p: Vector3 = Vector3(0,0.4,-0.55)*(height/1.86)
		var result := Outcome.assess({"hit":true,"quality":1,"platform_coord":Platform.coordinates(shape,p)},shape,p,0,Vector3.ZERO,0)
		check(result.recovery == "knee","Bottom-third mapping scales with physique")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await physics_frame
	var captured := []
	lab.receive_resolved.connect(func(event: Dictionary): captured.append(event))
	lab.ball_active = true
	lab.locked_action = 0
	lab.selected = 0
	lab.locked_charge = 0.1
	lab.armed = true
	lab.ball.position = lab.player.position+Vector3(0,0.95,-0.55)*(float(lab.athlete.build.height)/1.86)
	lab.ball_velocity = Vector3(0,-3,15)
	lab.ball_shot = Charge.shot("attack",0.8,"test")
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration-0.22
	lab._contact()
	check(captured.size() == 1 and captured[0].recovery == "blown_away","Actual player contact publishes recovery event")
	check(lab.last_contact_result.receive_outcome.outcome == "blown_away","Immutable player contact retains outcome evidence")
	lab._emit_external_impact("training_bot_0",0,Vector3(0,-3,15),sample(right,0.1,0.8))
	check(captured.size() == 2 and captured[1].actor == "training_bot_0" and captured[1].recovery == "fall_roll","Bot dispatch publishes same outcome contract")
	lab.queue_free()
	await process_frame
	print("RECEIVE OUTCOME: %d / %d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
