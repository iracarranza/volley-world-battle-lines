extends "res://scripts/map_drills.gd"
## Base for Workouts: Solo drills that need no ball. They are drills as far as the lab is concerned (it drives them through the same calls as the
## Box Jump), but they are timed runs: a completion earns XP and HP and counts toward a sub-attribute (WorkoutProgress), and the Workout then
## rests for 30 s. Leaving the area or running out of time abandons the run (nothing is lost but the time and Stamina).
const Progress := preload("res://scripts/workout_progress.gd")
const REACTIVATE_SECONDS := 30.0
enum Phase { READY, ACTIVE, COOLDOWN }
var phase := Phase.READY
var anchor := Vector3.ZERO
var title := "WORKOUT"
var subattribute := ""
var xp_reward := 20
var hp_reward := 10.0
var time_limit := 20.0
var elapsed := 0.0
var cooldown := 0.0
var completions := 0
var zone := Rect2(-4, -12, 8, 16) # local x, z of the area that counts as being at the Workout
var status_label: Label3D
var last_progress: Dictionary = {}

func setup(host: Node3D, _anchors: Dictionary = {}) -> void:
	lab = host
	box_enabled = false
	spike_enabled = false
	_build_course()
	status_label = Label3D.new()
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 28
	status_label.pixel_size = 0.008
	status_label.position = anchor + Vector3(0, 3.6, 0)
	add_child(status_label)
	lab.world_builder.world_label(title, anchor + Vector3(0, 0.2, 2.2), 32, lab.GOLD)
	detail = "I to start / %s" % title
	_refresh_label()

# Subclasses build their geometry here (everything in world coordinates around `anchor`).
func _build_course() -> void:
	pass

func _begin_run() -> void:
	pass

func _tick_active(_dt: float) -> void:
	pass

func _reset_run() -> void:
	steps_done = 0

func in_zone() -> bool:
	var p: Vector3 = lab.player.position - anchor
	return interaction_enabled and zone.has_point(Vector2(p.x, p.z))

func in_box_zone() -> bool: return false
func in_spike_zone() -> bool: return false
func holding_ball() -> bool: return false

# One-way decks work as in the Box Jump, but are live anywhere inside this Workout's own area.
func update_one_way() -> void:
	if lab == null or one_way.is_empty():
		return
	var feet: float = lab.player.position.y
	if feet < 0.0 or not in_zone():
		return
	var settling: bool = lab.player.velocity.y <= 0.01
	for platform in one_way:
		var solid: bool = settling and feet >= float(platform.top) - ONE_WAY_MARGIN
		if solid == bool(platform.solid):
			continue
		platform.solid = solid
		if solid:
			lab.player.remove_collision_exception_with(platform.body)
		else:
			lab.player.add_collision_exception_with(platform.body)

# Ordered landings (Inclined Obstacles, Salmon Ladder): `step_tops` are deck tops (world), `step_sizes` their footprints.
var step_tops: Array = []
var step_sizes: Array = []
var steps_done := 0

func _add_step(top: Vector3, size: Vector2, tint: Color) -> void:
	one_way.append(_add_deck(self, top, size, tint))
	step_tops.append(top)
	step_sizes.append(size)
	var number: Label3D = Label3D.new()
	number.text = str(step_tops.size())
	number.font_size = 40
	number.pixel_size = 0.008
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.position = top + Vector3(0, 0.7, 0)
	add_child(number)

# Advances `steps_done` when the player lands on the next deck; falling to the ground after the first landing loses the climb. Returns true on the last.
func _step_tick(label: String) -> bool:
	if not lab.player.is_on_floor() or steps_done >= step_tops.size():
		return false
	var next: Vector3 = step_tops[steps_done]
	var half: Vector2 = (step_sizes[steps_done] as Vector2) * 0.5
	var p: Vector3 = lab.player.position
	if absf(p.x - next.x) <= half.x - 0.1 and absf(p.z - next.z) <= half.y - 0.1 and absf(p.y - next.y) < 0.16:
		steps_done += 1
		lab.athlete.spend_resolved(float(lab.athlete.stamina_quote("drill_step").total))
		if steps_done >= step_tops.size():
			return true
		detail = "%s / %d of %d" % [label, steps_done, step_tops.size()]
		lab._message(detail)
	elif steps_done > 0 and p.y < 0.2:
		steps_done = 0
		detail = "Fell / %s starts over" % label
		lab._message(detail)
	return false
func economy() -> bool: return false

func running() -> bool:
	return phase == Phase.ACTIVE

func interact() -> void:
	match phase:
		Phase.READY:
			if in_zone():
				lab.station.stop()
				clear_preparation()
				phase = Phase.ACTIVE
				elapsed = 0.0
				_begin_run()
				detail = "%s / go" % title
		Phase.ACTIVE:
			_abandon("%s stopped" % title)
		_:
			detail = "%s / rests for %ds" % [title, ceili(cooldown)]
	lab._message(detail)
	_refresh_label()

func _abandon(reason: String) -> void:
	phase = Phase.READY
	_reset_run()
	detail = "%s / I to retry" % reason

func _complete(extra: String = "") -> void:
	phase = Phase.COOLDOWN
	cooldown = REACTIVATE_SECONDS
	completions += 1
	reward(xp_reward, hp_reward, 0.0)
	last_progress = Progress.record(lab.athlete, subattribute) if subattribute != "" else {}
	var growth := ""
	if not last_progress.is_empty():
		growth = " / %s %s" % [subattribute.capitalize(), "+1 (now %d)" % int(last_progress.rating) if last_progress.gained else "%d of %d" % [last_progress.count, last_progress.needed]]
	detail = "%s COMPLETE / +%d lab XP%s%s" % [title, xp_reward, growth, extra]
	_reset_run()
	lab._message(detail)

func tick(dt: float) -> void:
	if phase != Phase.ACTIVE:
		return
	if not in_zone():
		_abandon("Left %s" % title)
		return
	elapsed += dt
	_tick_active(dt)
	if phase == Phase.ACTIVE and elapsed >= time_limit:
		_abandon("%s timed out" % title)
		lab._message(detail)

# Called for every Workout each frame, near or not: the rest timer and the label.
func tick_setup(dt: float) -> void:
	if phase == Phase.COOLDOWN:
		cooldown = maxf(0.0, cooldown - dt)
		if cooldown <= 0.0:
			phase = Phase.READY
			detail = "%s / ready" % title
	_refresh_label()

func _refresh_label() -> void:
	if not is_instance_valid(status_label):
		return
	var text := ""
	match phase:
		Phase.READY: text = "%s ACTIVE / I to start" % title
		Phase.ACTIVE: text = "%s / %.0fs left" % [title, maxf(0.0, time_limit - elapsed)]
		_: text = "%s / reactivates in %ds" % [title, ceili(cooldown)]
	if status_label.text != text:
		status_label.text = text

func on_contact(_action: int) -> void: pass
func sweep_ball(_previous: Vector3, _dt: float) -> bool: return false
func on_ball_down() -> void: pass

func reset() -> void:
	phase = Phase.READY
	cooldown = 0.0
	_reset_run()
	detail = "I to start %s" % title

func hud_text() -> String:
	return "%s / I START / STOP\n%s\nLab XP earned: %d" % [title, detail, earned_xp]
