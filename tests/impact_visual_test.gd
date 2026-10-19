extends "res://tests/support/test_case.gd"
func _initialize() -> void:
	call_deferred("run")
func event(id: String, sweet: bool = false, action: int = 2) -> Dictionary:
	return {"id":id,"action":action,"physical_hit":true,"sweet":sweet,"point":Vector3(2,2,4),"incoming_velocity":Vector3(0,-4,10),"outgoing_velocity":Vector3(0,2,-18)}
func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	await physics_frame
	var fx = lab.impact_visual
	var pooled_ids := []
	for visual in fx.pool:
		pooled_ids.append(visual.root.get_instance_id())
	var stamina: float = lab.athlete.stamina
	var ball_velocity: Vector3 = lab.ball_velocity
	var invalid := event("miss")
	invalid.physical_hit = false
	lab.moc.begin(invalid)
	check(fx.live.is_empty(), "Misses cannot create impact effects")
	lab.moc.begin(event("ordinary"))
	check(fx.live.size() == 1 and not lab.moc.active, "Real impact creates visual even with MoC slowdown disabled")
	check(fx.live[0].root.position == Vector3(2,2,4), "Impact anchors at immutable contact point")
	var before_size: Vector3 = fx.live[0].shell.scale
	var axis: Vector3 = (Vector3(0,2,-18)-Vector3(0,-4,10)).normalized()
	check(fx.live[0].axis.distance_to(axis) < 0.00001, "Shell flattens along actual velocity change")
	lab.ball.position += Vector3(9,1,9)
	fx.tick(0.04)
	check(fx.live[0].root.position == Vector3(2,2,4), "Shell stays behind as ball departs")
	check(fx.live[0].shell.scale.length() > before_size.length(), "Shell expands after impact")
	check(lab.athlete.stamina == stamina and lab.ball_velocity == ball_velocity, "Presentation does not alter resources or ball flight")
	lab.moc.begin(event("ordinary"))
	check(fx.live.size() == 1, "Duplicate contact cannot flash twice")
	lab.moc.begin(event("sweet",true))
	check(fx.live.size() == 2 and fx.live[1].sweet and fx.live[1].duration > fx.live[0].duration and fx.live[1].color != fx.live[0].color, "Sweet hit adds longer gold emphasis")
	lab._emit_external_impact("bot",3,Vector3(0,0,20),{"hit":true,"sweet":false})
	check(fx.live[-1].profile == "stop" and fx.live[-1].point == lab.ball.position, "Bot block uses tight stop profile at correct point")
	var receive := event("receive",false,0)
	receive.outgoing_velocity = Vector3(0,2,-2)
	lab.moc.begin(receive)
	check(fx.live[-1].profile == "boom", "Absorbed fast receive uses soft spreading profile")
	var shank := event("shank")
	shank.charge_match = {"matched":false}
	lab.moc.begin(shank)
	check(fx.live[-1].color == Color("f29a88"), "Charge shank uses subdued warm emphasis")
	var count: int = fx.live.size()
	var elapsed: float = fx.live[0].age
	lab.paused = true
	fx.tick(1)
	check(fx.live.size() == count and fx.live[0].age == elapsed, "Pause freezes visual lifecycle")
	lab.paused = false
	fx.tick(0.5)
	check(fx.live.is_empty() and fx.pool.size() == fx.MAX_LIVE, "Effects expire and return all nodes to pool")
	for index in range(24):
		fx.play(event("pooled-%d" % index))
	check(fx.live.size() == fx.MAX_LIVE and fx.get_child_count() == fx.MAX_LIVE, "Dense impacts have bounded live effects")
	lab._reset()
	check(fx.live.is_empty() and fx.pool.size() == fx.MAX_LIVE, "Reset clears pending visuals and restores pool")
	lab.moc.enabled = false
	lab.ball_active = true
	lab.locked_action = 0
	lab.locked_charge = 0.65
	lab.selected = 0
	lab.armed = true
	lab.ball.position = lab.player.position+lab._raw_hurtbox_definition(0).center
	lab.ball_velocity = Vector3(0,-4,12)
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration-0.22
	lab._contact()
	check(fx.live.size() == 1 and fx.live[0].sweet and fx.live[0].point == lab.last_contact_result.point, "Actual clean player receive emits one sweet impact visual")
	check(fx.get_child_count() == fx.MAX_LIVE and fx.pool.size()+fx.live.size() == fx.MAX_LIVE,"Contact never allocates additional visual nodes")
	check(fx.live[0].root.get_instance_id() in pooled_ids,"Actual contact reuses a startup visual")
	print("IMPACT VISUAL: %d / %d passed" % [checks-failures,checks])
	lab.queue_free()
	await process_frame
	quit(1 if failures else 0)
