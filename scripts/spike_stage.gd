extends RefCounted

# The spike swing, from VWM's SpikeBiomechanics / AttackActionBiomechanics, posed through the
# pose library's spine and joint channels. VWM staggers the joints so the legs extend before the
# trunk arches, the trunk before the shoulder, and the elbow opens last; this keeps that timing
# and only changes where the numbers land: the trunk's pitch and twist become hip hinge, waist
# and chest, instead of tipping the whole body.
#
# Phase: -0.62 plant/takeoff, -0.40 takeoff ends, -0.22 cock, 0 contact, 0.45 follow-through ends,
# 1.0 landing recovered. Contact is nominally at the top of the jump.
const Library := preload("res://scripts/pose_library.gd")
const Execution := preload("res://scripts/contact_execution.gd")
const Attack := preload("res://vendor/vwm/construction/scripts/data/attack_action_biomechanics.gd")
const Spike := preload("res://vendor/vwm/construction/scripts/data/spike_biomechanics.gd")
const BASE_POSE := "ready_stance"
# Share of the chest's turn and lean carried by the waist; the rest is the upper back.
const WAIST_SHARE := 0.4
const ARM_DIRECTION_GAIN := 1.65
const CHEST_TURN_LIMIT := 24.0

# The swing has two clocks. Until the click the body only loads: from takeoff to the cocked position (the
# striking arm back behind the head, the other arm pointing at the ball) and it holds there. The click starts
# the strike, which takes STRIKE_SECONDS to reach contact (phase 0) and waits there; follow-through starts when
# the ball is struck (`hit_time`, in swing-clock seconds) or when the contact window closes without a hit.
const LOADED := -0.30
const STRIKE_SECONDS := Execution.SPIKE_PEAK
const FOLLOW_SECONDS := 0.30
# A ball struck before the strike has finished (a click right as the ball is in reach) used to snap the arm from the loaded pose to contact in
# one frame. The arm now carries on through the rest of the strike in this long, and the follow-through starts from contact.
const CATCH_SECONDS := 0.09

static func phase_for(air_time: float, flight_time: float, swing_time: float = -1.0, hit_time: float = -1.0) -> float:
	if swing_time < 0.0:
		var f := clampf(air_time / maxf(flight_time, 0.001), 0.0, 1.0)
		return lerpf(Spike.PLANT_END, LOADED, smoothstep(0.0, 0.45, f))
	if hit_time >= 0.0:
		var since := swing_time - hit_time
		var struck_at := swing_phase(hit_time)   # where the arm had got to when the ball was struck
		if since < CATCH_SECONDS and struck_at < -0.001:
			return lerpf(struck_at, 0.0, smoothstep(0.0, 1.0, since / CATCH_SECONDS))
		var after := since - (CATCH_SECONDS if struck_at < -0.001 else 0.0)
		return lerpf(0.0, Spike.FOLLOW_END, clampf(after / FOLLOW_SECONDS, 0.0, 1.0))
	return swing_phase(swing_time)

# The striking shoulder marks the sweep. Through the 0.2 s the active slice crosses the hurtbox, the shoulder turns at an even rate from its cocked
# angle (the slice behind the athlete) to the extension at the peak (the slice overhead) and on to the follow-through angle as the slice reaches
# the front, so the rotation of the arm is the timing: where it is, is where the strike is. The phase it needs is found from the pose's own
# shoulder curve, which is not linear in phase.
const SWEEP_SHOULDER := "shoulder_pitch:Right"
static var _shoulder_table: Array = [] # [phase, shoulder pitch], phases from the cock to the end of the follow-through

static func _shoulder_curve() -> Array:
	if _shoulder_table.is_empty():
		var phase := -0.22
		while phase <= Spike.FOLLOW_END + 0.0001:
			_shoulder_table.append([phase, float(pose_for(phase, 1.0)[SWEEP_SHOULDER])])
			phase += 0.01
	return _shoulder_table

static func shoulder_at(phase: float) -> float:
	var table := _shoulder_curve()
	var index := clampi(int((phase - float(table[0][0])) / 0.01), 0, table.size() - 2)
	var low: Array = table[index]
	var high: Array = table[index + 1]
	return lerpf(float(low[1]), float(high[1]), clampf((phase - float(low[0])) / (float(high[0]) - float(low[0])), 0.0, 1.0))

# The phase at which the striking shoulder is at `angle` (the pitch falls as the arm goes over, so the table is searched from the cock onward).
static func phase_at_shoulder(angle: float) -> float:
	var table := _shoulder_curve()
	for index in range(table.size() - 1):
		var low: Array = table[index]
		var high: Array = table[index + 1]
		if angle >= float(high[1]):
			var span := float(low[1]) - float(high[1])
			return lerpf(float(low[0]), float(high[0]), clampf((float(low[1]) - angle) / maxf(span, 0.0001), 0.0, 1.0))
	return float(table[table.size() - 1][0])

static func swing_phase(age: float) -> float:
	if age < Execution.SPIKE_WINDUP:
		# Deliberate cocking motion; contact is disabled throughout this lead-in.
		return lerpf(LOADED, -0.22, smoothstep(0.0, Execution.SPIKE_WINDUP, age))
	var back := shoulder_at(-0.22)
	var extension := shoulder_at(0.0)
	var follow := shoulder_at(Spike.FOLLOW_END)
	var half := (Execution.SPIKE_END - Execution.SPIKE_WINDUP) * 0.5
	if age <= STRIKE_SECONDS:
		return phase_at_shoulder(lerpf(back, extension, clampf((age - Execution.SPIKE_WINDUP) / half, 0.0, 1.0)))
	return phase_at_shoulder(lerpf(extension, follow, clampf((age - STRIKE_SECONDS) / half, 0.0, 1.0)))

# The swing at `phase` as a flat pose (see PoseLibrary.flatten), unclamped so the shoulder can
# travel through the overhead angles the swing uses.
# `hand` is +1 for a right-handed spiker, -1 for left.
# `context` aims the swing: "ball_local" (Vector3, the ball in the body's frame: x right, y up, -z ahead) bends the
# reach to where the ball is, and "shot_yaw" (radians, positive to the left of the body's forward) carries the
# follow-through on in the direction of the shot.
static func pose_for(phase: float, hand: float, power: float = 0.5, attack_type: String = "Power swing", context: Dictionary = {}) -> Dictionary:
	var swing := Attack.resolve(phase, hand, power, attack_type)
	var flat := Library.flat_pose(BASE_POSE)
	var strike: String = "Left" if hand < 0.0 else "Right"
	var guide: String = "Right" if hand < 0.0 else "Left"
	var strike_index := 0 if strike == "Left" else 1
	var guide_index := 1 - strike_index
	# Trunk. VWM's pitch is negative leaning forward; the pelvis takes its share and the chest the rest.
	var total_pitch := rad_to_deg(float(swing.torso_pitch_radians))
	var pelvis_pitch := total_pitch * float(swing.get("pelvis_pitch_share", 1.0))
	var chest_pitch := total_pitch + rad_to_deg(float(swing.get("chest_pitch_extra_radians", 0.0)))
	var chest_over_pelvis := chest_pitch - pelvis_pitch
	flat["hip_hinge"] = -pelvis_pitch
	flat["lumbar_flexion"] = -chest_over_pelvis * WAIST_SHARE
	flat["thoracic_flexion"] = -chest_over_pelvis * (1.0 - WAIST_SHARE)
	var twist := float(swing.torso_twist_degrees) + float(swing.get("chest_twist_extra_degrees", 0.0))
	flat["lumbar_twist"] = twist * WAIST_SHARE
	flat["thoracic_twist"] = twist * (1.0 - WAIST_SHARE)
	var roll := float(swing.get("adjustment_roll_degrees", 0.0)) + float(swing.get("chest_roll_degrees", 0.0))
	flat["lumbar_bend"] = roll * WAIST_SHARE
	flat["thoracic_bend"] = roll * (1.0 - WAIST_SHARE)
	# Legs: the lead leg is the striking side's.
	var stagger := float(swing.get("landing_stagger_degrees", 0.0))
	flat["hip:%s" % strike] = float(swing.lead_hip_degrees) + stagger
	flat["hip:%s" % guide] = float(swing.trail_hip_degrees) - stagger
	for side in Library.SIDES:
		flat["knee:%s" % side] = float(swing.knee_degrees)
		flat["abduction:%s" % side] = 0.0
		flat["hip_rotation:%s" % side] = 0.0
	# Arms. The swing gives node rotations; a channel is the node angle times the side's sign.
	var sign_roll: Array = Library.CHANNELS.shoulder_roll.sign
	var sign_turn: Array = Library.CHANNELS.shoulder_rotation.sign
	flat["shoulder_pitch:%s" % strike] = float(swing.striking_shoulder_degrees)
	flat["shoulder_rotation:%s" % strike] = float(swing.get("striking_internal_rotation_degrees", 0.0)) * float(sign_turn[strike_index])
	flat["shoulder_roll:%s" % strike] = float(swing.striking_abduction_degrees) * float(sign_roll[strike_index])
	flat["elbow:%s" % strike] = float(swing.striking_elbow_degrees)
	flat["shoulder_pitch:%s" % guide] = float(swing.guide_shoulder_degrees)
	flat["shoulder_roll:%s" % guide] = 0.0
	flat["shoulder_rotation:%s" % guide] = 0.0
	flat["elbow:%s" % guide] = float(swing.guide_elbow_degrees)
	if not context.is_empty():
		_aim(flat, phase, hand, strike, strike_index, context)
	# The head keeps looking at the ball: chin up through the swing.
	flat["neck_flexion"] = lerpf(0.0, -14.0, smoothstep(-0.5, -0.1, phase)) * (1.0 - smoothstep(0.1, 0.5, phase))
	# Preserve facing while allowing the trunk to contribute to cross-body swings.
	var facing_weight := lerpf(0.65,0.60,smoothstep(LOADED,0.0,phase))
	var chest_turn := clampf((float(flat["lumbar_twist"])+float(flat["thoracic_twist"]))*facing_weight,-CHEST_TURN_LIMIT,CHEST_TURN_LIMIT)
	flat["lumbar_twist"] = chest_turn*WAIST_SHARE
	flat["thoracic_twist"] = chest_turn*(1.0-WAIST_SHARE)
	flat["neck_twist"] = -chest_turn
	return flat

# Bend the swing toward the ball. All of it grows in with the strike, so the loaded pose is the same wherever the
# ball is and the arm only commits to the ball once the click starts the swing.
static func _aim(flat: Dictionary, phase: float, hand: float, strike: String, strike_index: int, context: Dictionary) -> void:
	var reach := smoothstep(Spike.STRIKE_START, 0.0, phase)
	var follow := smoothstep(0.0, Spike.FOLLOW_END, phase) * (1.0 - smoothstep(0.6, 0.95, phase))
	var ball: Vector3 = context.get("ball_local", Vector3(0.0, 2.3, -0.4))
	var yaw: float = clampf(float(context.get("shot_yaw", 0.0))*ARM_DIRECTION_GAIN,-deg_to_rad(65),deg_to_rad(65))
	var toward := clampf(ball.x * hand / 0.6, -1.0, 1.0)      # + the ball is on the striking arm's side
	var ahead := clampf((-ball.z - 0.35) / 0.5, -1.0, 1.0)    # + the ball is well in front
	var high := clampf((ball.y - 2.2) / 0.5, -1.0, 1.0)       # + the ball is above the usual contact height
	var distance := clampf(Vector2(ball.x, ball.z).length() / 1.0, 0.0, 1.0)
	var sign_roll: Array = Library.CHANNELS.shoulder_roll.sign
	var sign_turn: Array = Library.CHANNELS.shoulder_rotation.sign
	# The arm opens out toward a ball on its side and crosses toward one on the other side.
	flat["shoulder_roll:%s" % strike] = float(flat["shoulder_roll:%s" % strike]) + toward * 48.0 * reach
	# A ball out in front pulls the arm over the top further; a high one holds it nearer vertical.
	flat["shoulder_pitch:%s" % strike] = float(flat["shoulder_pitch:%s" % strike]) - ahead * 20.0 * reach + high * 10.0 * reach
	flat["elbow:%s" % strike] = float(flat["elbow:%s" % strike]) * (1.0 - 0.5 * distance * reach)
	# The body turns and leans toward the ball: chest and waist twist toward it, and the waist bends forward for a ball ahead.
	flat["thoracic_twist"] = float(flat["thoracic_twist"]) - clampf(ball.x / 0.6, -1.0, 1.0) * 24.0 * reach
	flat["lumbar_bend"] = float(flat["lumbar_bend"]) - clampf(ball.x / 0.6, -1.0, 1.0) * 10.0 * reach
	flat["lumbar_flexion"] = float(flat["lumbar_flexion"]) + maxf(ahead, 0.0) * 12.0 * reach
	# The follow-through carries on toward where the ball is going. The arm turns with the shot and a shot across
	# the body draws the arm across it.
	var weight := reach
	flat["shoulder_rotation:%s" % strike] = float(flat["shoulder_rotation:%s" % strike]) + rad_to_deg(yaw * 1.10) * float(sign_turn[strike_index]) * weight
	flat["thoracic_twist"] = float(flat["thoracic_twist"]) + rad_to_deg(yaw * 0.35) * weight
	var across := clampf(yaw * hand / 0.6, -1.0, 1.0)
	flat["shoulder_roll:%s" % strike] = float(flat["shoulder_roll:%s" % strike]) + across * 46.0 * (reach*0.40+follow*0.60)
	flat["thoracic_twist"] = float(flat["thoracic_twist"]) + clampf(yaw / 0.6, -1.0, 1.0) * 14.0 * follow

static func apply(body: Node3D, phase: float, hand: float, power: float = 0.5, attack_type: String = "Power swing", context: Dictionary = {}) -> void:
	Library.apply(body, Library.from_flat(pose_for(phase, hand, power, attack_type, context), false), 1.0)
