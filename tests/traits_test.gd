extends SceneTree
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(lab: Node3D, frames: int = 4) -> void:
	for frame in range(frames):
		lab._physics_process(1.0 / 60.0)
		await physics_frame

func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	var Geometry = load("res://scripts/contact_geometry.gd")
	# Receive zones: widest edges are sour, centre stays clean.
	var receive: Dictionary = Geometry.definition(0, 1.86, 2.3, false, 1.0)
	var edge_x: float = receive.size.x * 0.5 * 0.9
	check(Geometry.evaluate(receive, receive.center + Vector3(edge_x, 0, 0)).zone == "SOUR SPOT", "Receive edge is a sour spot")
	check(Geometry.evaluate(receive, receive.center + Vector3(-edge_x, 0, 0)).get("edge", false), "Both edges are sour spots")
	check(Geometry.evaluate(receive, receive.center).zone == "CLEAN", "Receive centre is clean")
	check(not Geometry.evaluate(receive, receive.center + Vector3(5, 0, 0)).hit, "Outside the receive hurtbox misses")
	var set_shape: Dictionary = Geometry.definition(1, 1.86, 2.3, false, 1.0)
	check(Geometry.evaluate(set_shape, set_shape.center + Vector3(0.7, 0, 0)).zone != "SOUR SPOT", "Set has no sour edges")
	# Ownership
	var config: Dictionary = Store.blank()
	check(Store.owned_traits(config).is_empty(), "Base athlete owns no traits")
	config.speed = 66.0
	check(Store.owned_traits(config) == ["Quick Step"], "Quick Step unlocks at SPD 66")
	config.power = 70.0
	config.endurance = 70.0
	check("Power Serve" in Store.owned_traits(config) and "Rolling Receive" in Store.owned_traits(config), "Attribute thresholds grant traits")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	await settle(lab, 40)
	check(lab.athlete.traits.is_empty(), "Default lab athlete has no traits")
	# Quick Step
	lab.athlete.traits.assign(["Quick Step"])
	lab.armed = false
	lab.charging = false
	lab._quick_step()
	check(lab.quick_step_time == 0.0, "Quick Step needs a charged action")
	lab.armed = true
	lab.locked_action = 0
	var hp: float = lab.athlete.hp
	var sta: float = lab.athlete.stamina
	var jump_cost: float = lab.athlete.jump_stamina_cost()
	var tap := InputEventKey.new()
	tap.keycode = KEY_A
	tap.pressed = true
	lab.tap_times.clear()
	lab._unhandled_input(tap)
	check(lab.quick_step_time == 0.0, "A single tap does not fire Quick Step")
	lab._unhandled_input(tap)
	check(lab.quick_step_time > 0.0 and is_equal_approx(lab.quick_step_cooldown, 5.0), "Double-tap fires Quick Step with the 5s exploration cooldown")
	check(is_equal_approx(hp - lab.athlete.hp, 3.0), "Quick Step costs 3 HP")
	check(is_equal_approx(sta - lab.athlete.stamina, jump_cost * 0.5), "Quick Step costs half a jump's Stamina")
	var after: float = lab.athlete.stamina
	lab._unhandled_input(tap)
	lab._unhandled_input(tap)
	check(is_equal_approx(lab.athlete.stamina, after), "Cooldown blocks a second burst")
	var start: Vector3 = lab.player.position
	await settle(lab, 12)
	check(start.distance_to(lab.player.position) > 0.8, "Quick Step moves the athlete")
	check(lab.quick_step_cooldown < 5.0 and lab.quick_step_cooldown > 4.0, "Cooldown ticks down")
	lab.quick_step_cooldown = 0.0
	lab.quick_step_time = 0.0
	lab.athlete.stamina = 100.0
	lab.ball_active = true
	lab.armed = false
	lab.charging = true
	lab._quick_step(Vector3(0, 0, -1))
	check(is_equal_approx(lab.quick_step_cooldown, 8.0), "In-rally cooldown is 8s and charging counts as charged")
	lab.ball_active = false
	lab.charging = false
	lab.armed = false
	# Power Serve
	lab.athlete.traits.assign([])
	var base: float = lab.athlete.serve_speed_factor(0.6)
	lab.athlete.traits.assign(["Power Serve"])
	var boosted: float = lab.athlete.serve_speed_factor(0.6)
	check(is_equal_approx(base, 1.0) and boosted > 1.0 and boosted < 1.1, "Power Serve gives a low fixed bonus per charge")
	check(is_equal_approx(lab.athlete.effective_serve_charge(0.6)-0.6,0.12) and is_equal_approx(lab.athlete.effective_serve_charge(1.0)-1.0,0.12), "Power Serve adds a fixed 12 charge points at every input level")
	# Rolling Receive
	lab._reset()
	lab.athlete.traits.assign(["Rolling Receive"])
	lab.player.position = Vector3(0, 0.03, 5)
	lab.locked_action = 0
	lab.selected = 0
	lab.locked_charge = 0.5
	lab.facing_yaw = 0.0
	var definition: Dictionary = lab._raw_hurtbox_definition(0)
	lab.ball_active = true
	lab.ball.position = lab.player.position + definition.center + Vector3(definition.size.x * 0.5 * 0.9, 0, 0)
	lab.ball_velocity = Vector3(0, -1, -1)
	lab.outgoing = false
	var hp2: float = lab.athlete.hp
	var normal_cost: float = lab.athlete.contact_cost(0, 1).y * lerpf(0.7, 1.3, 0.5)
	lab._contact()
	check(lab.last_quality == "ROLLING RECEIVE" and lab.roll_lock > 0.0, "Edge receive procs Rolling Receive")
	check(lab.ball_velocity.y > 3.0 and lab.ball_velocity.z < 0.0, "Roll sends the ball high in the facing direction")
	check(is_equal_approx(hp2 - lab.athlete.hp, normal_cost + 5.0), "Roll costs 5 HP on top of the receive")
	lab.athlete.build.name = "TEST / L"
	lab.athlete.hp = 100.0
	lab.contacts = 0
	lab.side_contacts.assign([0, 0])
	lab.ball.position = lab.player.position + definition.center + Vector3(definition.size.x * 0.5 * 0.9, 0, 0)
	lab.roll_lock = 0.0
	lab.last_contact = -10.0
	var libero_normal: float = lab.athlete.contact_cost(0, 1).y * lerpf(0.7, 1.3, 0.5)
	lab._contact()
	check(is_equal_approx(100.0 - lab.athlete.hp, libero_normal + 5.0), "Libero discount does not apply to the roll")
	var before: Vector3 = lab.player.position
	lab._physics_process(1.0 / 60.0)
	lab.roll_lock = 0.5
	lab._unhandled_input(InputEventKey.new())
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	lab.selected = 3
	lab._unhandled_input(key)
	check(lab.selected == 3, "Actions are locked while rolling")
	lab.roll_lock = 0.0
	lab.athlete.traits.assign([])
	lab._reset()
	lab.athlete.build.name = "BALANCED / OH"
	lab.player.position = Vector3(0, 0.03, 5)
	lab.ball.position = lab.player.position + definition.center + Vector3(definition.size.x * 0.5 * 0.9, 0, 0)
	lab.locked_action = 0
	lab.ball_active = true
	lab._contact()
	check(lab.last_quality == "SOUR SPOT" and lab.roll_lock == 0.0, "Without the trait an edge receive is just a sour spot")
	print("TRAIT CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
