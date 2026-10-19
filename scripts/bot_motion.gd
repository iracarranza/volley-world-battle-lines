extends RefCounted
const Pose := preload("res://scripts/athlete_pose.gd")
const Approach := preload("res://scripts/approach_run.gd")
var plans: Dictionary = {}

func begin(slot: int, actor: Node3D, target: Vector3, time: float, tracking: bool, gravity: float, move_speed: float = -1.0, aim_yaw: float = NAN, explosiveness: float = 1.0) -> void:
	var action := slot % 4
	var height := maxf(target.y, 0.0)
	var rise := minf(sqrt(2.0 * height / gravity), time * 0.65) if height > 0.01 else 0.15
	var fall := rise
	rise /= maxf(explosiveness,0.1)
	var approach := minf(Approach.DURATION * Approach.LAUNCH_START/maxf(explosiveness,0.1), maxf(0.05, time - rise)) if action == 2 else minf(0.18, time - rise)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, actor.rotation.y if is_nan(aim_yaw) else aim_yaw)
	var ground := Vector3(target.x, 0, target.z)
	var start := ground - forward * 2.7 if tracking and action == 2 and move_speed < 0 else Vector3(actor.position.x, 0, actor.position.z)
	actor.position = start
	plans[slot] = {"elapsed": 0.0, "contact": time, "rise": rise, "fall":fall, "approach": approach, "height": height, "start": start, "ground": ground, "phase": "waiting", "move_speed": move_speed, "start_yaw": actor.rotation.y, "aim_yaw": actor.rotation.y if is_nan(aim_yaw) else aim_yaw}

func tick(dt: float, actors: Array[Node3D], rigs: Array[Dictionary], scales: Dictionary = {}) -> void:
	for slot in plans.keys():
		var step_dt: float = dt * float(scales.get(slot, 1.0))
		var plan: Dictionary = plans[slot]
		var actor := actors[slot]
		var rig: Dictionary = rigs[slot]
		plan.elapsed += step_dt
		var launch: float = plan.contact - plan.rise
		var approach_start: float = launch - plan.approach
		var progress := clampf((float(plan.elapsed) - approach_start) / maxf(plan.approach, 0.01), 0, 1)
		var step := Approach.step_index(progress * Approach.LAUNCH_START)
		var phase := Approach.step_phase(progress * Approach.LAUNCH_START)
		# Long bound, short step, inward plant. Unequal times and distances.
		var ends := [0.0, 0.64, 0.85, 1.0]
		var travel := lerpf(ends[mini(step, 2)], ends[mini(step, 2) + 1], smoothstep(0, 1, phase)) if progress < 1 else 1.0
		var desired := Vector3(plan.start).lerp(plan.ground, travel)
		if float(plan.get("move_speed", -1)) >= 0:
			desired = Vector3(actor.position.x, 0, actor.position.z).move_toward(plan.ground, float(plan.move_speed) * step_dt)
		actor.position = desired
		var airborne := float(plan.elapsed) >= launch
		if slot % 4 == 2:
			if not airborne:
				actor.rotation.y = lerp_angle(float(plan.start_yaw), float(plan.aim_yaw), progress)
			elif not plan.has("committed_yaw"):
				plan["committed_yaw"] = float(plan.aim_yaw)
				actor.rotation.y = plan.committed_yaw
			else:
				actor.rotation.y = plan.committed_yaw
		var air := (float(plan.elapsed) - launch) / maxf(plan.rise, 0.01)
		var drop := maxf(0,float(plan.elapsed)-float(plan.contact))/maxf(float(plan.get("fall",plan.rise)),0.01)
		actor.position.y = maxf(0,float(plan.height)*(1.0-pow(drop,2) if air > 1 else 1.0-pow(air-1.0,2))) if airborne else (0.16 * sin(phase * PI) if slot % 4 == 2 and step == 0 and progress > 0 else 0.0)
		plan.phase = "landing" if air > 1.0 else ("jump" if airborne else ("approach" if float(plan.elapsed) >= approach_start else "waiting"))
		Pose.base(rig.body, progress * TAU * 2, 2.5 if not airborne and progress > 0 and progress < 1 else 0, 0, false)
		if not airborne and slot % 4 == 2 and progress > 0 and progress < 1:
			var lead := Approach.lead_foot(step)
			rig.legs[lead].rotation.x = -sin(phase * PI) * [1.05, 0.65, 0.48, 0.0][step]
			rig.legs[1 - lead].rotation.x = sin(phase * PI) * 0.45
			if step == 2:
				rig.legs[lead].rotation.y = Approach.foot_turn(step)
		if airborne:
			for leg in rig.legs:
				leg.rotation.x = -0.25
				leg.get_node("Knee").rotation.x = -0.35
			if slot % 4 == 1:
				pass # Shared SetStage drives jump-set arms.
			elif slot % 4 == 3:
				for arm in rig.arms:
					arm.rotation.x = -2.9
					arm.get_node("Elbow").rotation.x = 0.0

		Pose.ground_feet(rig.body)
		if float(plan.elapsed) >= float(plan.contact) + float(plan.get("fall",plan.rise)):
			actor.position = Vector3(actor.position.x, 0, actor.position.z) if float(plan.get("move_speed", -1)) >= 0 else plan.ground
			Pose.base(rig.body, 0, 0, 0, false)
			Pose.ground_feet(rig.body)
			plans.erase(slot)
