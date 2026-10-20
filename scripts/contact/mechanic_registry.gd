extends RefCounted
## One vocabulary for runtime effects, editor units and ordered contact evidence.
const STAGES := ["geometry", "timing", "potency", "handling", "pressure_control", "redirection", "intent_transfer", "consequences"]
const LABELS := ["Contact Geometry", "Contact Timing", "Action Potency", "Incoming Handling", "Pressure Control", "Redirection", "Intent Transfer", "Contact Consequences"]
const EFFECT_KEYS := ["stride_speed", "spike_velocity", "serve_velocity", "platform_quality", "charge_tolerance", "flow_attack_velocity", "second_wind", "revenge_jump_power", "revenge_spike_velocity", "back_attack_velocity", "jump_stamina_threshold", "recovery", "stamina_recovery", "exertion_efficiency", "receive_control", "receive_absorption", "receive_redirection"] + ["flow_state", "broad_range", "vertical_reach", "court_vision", "placement", "ally_attack_charge_tolerance", "receive_charge_bonus", "mismatch_knockback", "mismatch_stamina_drain", "transition_speed_penalty", "inflicted_recovery_duration", "charge_aim_variance", "di_stamina_cost", "di_hp_cost", "di_cost_reduction", "explosiveness", "jump_power", "swing_power", "acceleration", "reaction_speed", "transition_speed", "ball_control", "timing", "stability", "cushioning", "work_rate", "capacity", "power", "speed", "accuracy", "endurance", "explosiveness_band", "jump_power_band", "swing_power_band", "explosiveness_band_cap", "jump_power_band_cap", "swing_power_band_cap"]
const EFFECTS := {
	"stride_speed": ["Stride Speed", "%", "consequences", [], "Increases movement acceleration after the Receive split step; reserved for a future trait."],
	"spike_velocity": ["Spike Velocity", " pp", "potency", [2], "Adds effective attack charge after Swing Power."],
	"serve_velocity": ["Serve Velocity", " pp", "potency", [4], "Adds effective serve charge."],
	"platform_quality": ["Platform Quality", " pts", "geometry", [0], "Improves receiving zone overlap; never changes matching or outer reach."],
	"charge_tolerance": ["Charge Tolerance", "%", "handling", [0,3], "Softens mismatch severity without manufacturing a charge match."],
	"flow_attack_velocity": ["Flow Attack Velocity", " pp", "potency", [2], "Adds attack charge while consuming Flow."],
	"second_wind": ["Second Wind", "%", "consequences", [], "Restores stamina when its fatigue condition activates."],
	"revenge_jump_power": ["Revenge Jump Power", " pts", "consequences", [], "Grants the existing pending jump benefit after a poor attack receive."],
	"revenge_spike_velocity": ["Revenge Spike Velocity", " pp", "potency", [2], "Grants the existing pending attack charge benefit."],
	"back_attack_velocity": ["Back Attack Velocity", " pp", "potency", [2], "Adds attack charge according to back-court depth."],
	"jump_stamina_threshold": ["Jump Stamina Threshold", "%", "potency", [], "Bypasses jump deterioration above this stamina threshold."],
	"recovery": ["Recovery", "%", "consequences", [], "Accelerates recovery from existing contact outcomes."],
	"stamina_recovery": ["Stamina Recovery", "%", "consequences", [], "Increases stamina regeneration."],
	"exertion_efficiency": ["Exertion Efficiency", "%", "consequences", [], "Reduces stamina expenditure."],
	"receive_control": ["Receive Control", "%", "pressure_control", [0], "Narrows uncontrolled receive output toward the intended pass; does not grant a match or sweet contact."],
	"receive_absorption": ["Receive Absorption", "%", "pressure_control", [0], "Damps residual impact speed on uncontrolled receives, especially low contacts."],
	"receive_redirection": ["Receive Redirection", "%", "redirection", [0], "Improves directional authority and reduces placement-sensitive scatter on uncontrolled receives."],
}

const EXTENSIONS := {
 "flow_state":["Flow State","%","consequences",[],"Multiplies positive Flow gains only."],
 "broad_range":["Broad Range","%","geometry",[],"Lateral reach and outer-zone leniency."],
 "vertical_reach":["Vertical Reach","%","geometry",[],"Vertical hurtbox stretch."],
 "court_vision":["Court Vision","%","redirection",[],"Directional influence angular authority."],
 "placement":["Placement","pp","intent_transfer",[1],"Set-carried attack transfer efficiency."],
 "ally_attack_charge_tolerance":["Ally Attack Charge Tolerance","%","intent_transfer",[1],"Set-carried support for the next allied attacker."],
 "receive_charge_bonus":["Receive Charge Bonus","pp","potency",[0],"Direct receive-charge additive, distinct from Cushioning rating."],
 "mismatch_knockback":["Mismatch Knockback","%","consequences",[4],"Serve-carried receiver knockback modifier."],
 "mismatch_stamina_drain":["Mismatch Stamina Drain","%","consequences",[4],"Serve-carried extra mismatch stamina loss."],
 "transition_speed_penalty":["Transition Speed Penalty","pts","consequences",[4],"Serve-carried temporary recovery stat penalty."],
 "inflicted_recovery_duration":["Inflicted Recovery Duration","s","consequences",[4],"Duration of a serve-inflicted modifier."],
 "charge_aim_variance":["Charge Aim Variance","deg","redirection",[],"Charge/DI dispersion, moderated by Ball Control."],
 "di_stamina_cost":["DI Stamina Cost","STA","consequences",[],"Configured full-DI stamina cost."],
 "di_hp_cost":["DI HP Cost","HP","consequences",[],"Configured full-DI HP cost."],
 "di_cost_reduction":["DI Cost Reduction","%","consequences",[],"Reduces configured DI costs."],
}

static func registered(key: String) -> bool:
	return EFFECTS.has(key) or EXTENSIONS.has(key) or key in preload("res://scripts/stat_tuning.gd").PARENTS or key in ["power","speed","accuracy","endurance"] or key in ["explosiveness_band","jump_power_band","swing_power_band","explosiveness_band_cap","jump_power_band_cap","swing_power_band_cap"]

static func metadata(key: String) -> Array:
	if EFFECTS.has(key): return EFFECTS[key]
	if EXTENSIONS.has(key): return EXTENSIONS[key]
	return [key.capitalize(),"bands" if (key.ends_with("_band") or key.ends_with("_band_cap")) else "pts","potency",[],"Effective runtime stat modifier; never changes eligibility."]

static func effect(key: String) -> Dictionary:
	if not registered(key):
		return {"label": key.capitalize(), "unit": "", "stage": "unsupported", "actions": [], "description": "Unsupported effect: preserved in the file but has no registered runtime mechanic."}
	var data: Array = metadata(key)
	return {"label": data[0], "unit": data[1], "stage": data[2], "actions": data[3], "description": data[4]}

static func applies(key: String, action: int) -> bool:
	return registered(key) and (metadata(key)[3].is_empty() or action in metadata(key)[3])

static func record(stage: String, evidence: Dictionary) -> Dictionary:
	return {"id": stage, "label": LABELS[STAGES.find(stage)], "evidence": evidence}

static func profile(action: int) -> String:
	return ["Receive Conditioning", "Set Isolation", "Attack Transfer", "Block Deflection", "Serve Delivery"][action]
