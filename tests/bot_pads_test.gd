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

func run() -> void:
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	lab.set_process(false)
	for i in 20:
		await physics_frame
	var pads = lab.bot_pads
	check(pads.pads.size() == 4, "Four pads, one per action")
	check(pads.in_zone() == -1, "Player starts off the pads")
	var bots_before: int = lab.training_bots.get_child_count()
	for index in range(4):
		lab.player.position = pads.pads[index].position + Vector3(0.3, 0.03, 0.2)
		check(pads.in_zone() == index, "Standing on pad %d is detected" % index)
		check(not pads.is_spawned(index), "Pad %d starts empty" % index)
		pads.interact()
		check(pads.is_spawned(index) and pads.pads[index].actor.position.is_equal_approx(pads.pads[index].bot_spot), "Interact spawns a bot at the bot spot (pad %d)" % index)
		pads.interact()
		check(not pads.is_spawned(index), "Interacting again despawns it (pad %d)" % index)
	for pad in pads.pads:
		check(absf(pad.position.z) > 15.0 and absf(pad.position.x) <= 12.0 and pad.position.z < 0.0, "Pads sit behind the court, clear of the lanes' other features")
	# Configuration is stored and clamped
	pads.set_config(2, "charge", 2.0)
	pads.set_config(2, "timing", -1.0)
	pads.set_config(2, "aim", 33.0)
	var config: Dictionary = pads.bot_config(2)
	check(is_equal_approx(config.charge, 1.0) and is_equal_approx(config.timing, -0.30) and is_equal_approx(config.aim, 35.0), "Config clamps and snaps to steps")
	check(config.action == 2 and not config.spawned, "Config reports action and spawn state")
	# I routes to the pad via the lab key handler, and only on a pad
	lab.player.position = pads.pads[1].position
	var key := InputEventKey.new()
	key.keycode = KEY_I
	key.pressed = true
	lab._unhandled_input(key)
	check(pads.is_spawned(1), "The I key spawns a bot when standing on a pad")
	lab._unhandled_input(key)
	check(not pads.is_spawned(1), "The I key despawns it again")
	# Keys tune only the pad under the player
	var tune := InputEventKey.new()
	tune.keycode = KEY_BRACKETRIGHT
	tune.pressed = true
	var before: float = pads.pads[1].config.charge
	pads._unhandled_input(tune)
	check(pads.pads[1].config.charge > before, "] raises the charge on the pad underfoot")
	lab.player.position = Vector3(0, 0.03, 5)
	var other: float = pads.pads[1].config.charge
	pads._unhandled_input(tune)
	check(is_equal_approx(pads.pads[1].config.charge, other), "Tuning keys do nothing off a pad")
	# The loop: a ball at the sweet spot, a hit at the contact time, a fresh ball every 5 seconds
	lab.player.position = pads.pads[2].position
	pads.set_config(2, "timing", 0.0)
	pads.set_config(2, "aim", 0.0)
	pads.interact()
	var pad: Dictionary = pads.pads[2]
	check(is_instance_valid(pad.ball) and pad.ball_state == "held" and pad.ball.position.is_equal_approx(pads.sweet_world(2)), "Spawning starts a loop with the ball held at the bot's sweet spot")
	check(pad.loops == 1, "First loop started on spawn")
	for i in range(int(0.9 * 60)):
		pads._physics_process(1.0 / 60.0)
	check(pad.ball_state == "held" and not pad.contacted, "The ball waits through the wind-up")
	for i in range(int(0.5 * 60)):
		pads._physics_process(1.0 / 60.0)
	check(pad.contacted and pad.ball_state == "flying", "The bot hits at the contact time")
	check(pad.ball_velocity.y > 0.0 and pad.ball_velocity.dot(pad.forward) > 0.0, "The ball leaves toward the pad")
	pads.set_config(2, "timing", -0.3)
	check(is_equal_approx(pads.contact_time(2), 0.9), "Timing shifts the contact time")
	pads.set_config(2, "timing", 0.0)
	var ball_before = pad.ball
	for i in range(int(2.8 * 60)):
		pads._physics_process(1.0 / 60.0)
	check(pad.loops == 1, "No new loop before 5 seconds (%d)" % pad.loops)
	for i in range(int(1.0 * 60)):
		pads._physics_process(1.0 / 60.0)
	check(pad.loops == 2 and pad.ball_state == "held" and not is_same(pad.ball, ball_before), "A fresh ball spawns at the sweet spot on the next loop")
	check(not is_instance_valid(ball_before) or ball_before.is_queued_for_deletion() or ball_before.get_parent() == null, "The previous ball is cleaned up")
	lab.paused = true
	var frozen: float = pad.time
	pads._physics_process(1.0)
	check(is_equal_approx(pad.time, frozen), "The loop pauses with the lab")
	lab.paused = false
	pads.despawn(2)
	check(pad.ball == null and not pads.is_spawned(2), "Despawn removes the bot and its ball")
	# Reset despawns everything and restores defaults
	pads.spawn(0)
	pads.spawn(3)
	lab._reset()
	check(not pads.is_spawned(0) and not pads.is_spawned(3), "Lab reset despawns every bot")
	check(is_equal_approx(pads.pads[1].config.charge, 0.65), "Lab reset restores pad defaults")
	check(lab.training_bots.get_child_count() == bots_before, "Pads never touch the training bots")
	print("BOT PADS CHECKS: %d passed / %d total" % [checks - failures, checks])
	quit(1 if failures else 0)
