extends RefCounted
## One vocabulary for runtime effects, editor units and ordered contact evidence.
const STAGES := ["geometry", "timing", "potency", "handling", "pressure_control", "redirection", "intent_transfer", "consequences"]
const LABELS := ["Contact Geometry", "Contact Timing", "Action Potency", "Incoming Handling", "Pressure Control", "Redirection", "Intent Transfer", "Contact Consequences"]
const EFFECT_KEYS := ["stride_speed", "spike_velocity", "serve_velocity", "platform_quality", "charge_tolerance", "flow_attack_velocity", "second_wind", "revenge_jump_power", "revenge_spike_velocity", "back_attack_velocity", "jump_stamina_threshold", "recovery", "stamina_recovery", "exertion_efficiency", "receive_control", "receive_absorption", "receive_redirection"]
const EFFECTS := {
	"stride_speed": ["Stride Speed", "%", "consequences", [], "Increases movement acceleration after the Receive split step; reserved for a future trait."],
	"spike_velocity": ["Spike Velocity", " pp", "potency", [2], "Adds effective attack charge after Swing Power."],
	"serve_velocity": ["Serve Velocity", " pp", "potency", [4], "Adds effective serve charge."],
	"platform_quality": ["Platform Quality", " pts", "geometry", [0], "Improves receiving zone overlap; never changes matching or outer reach."],
	"charge_tolerance": ["Charge Tolerance", "%", "handling", [0], "Softens mismatch severity without manufacturing a charge match."],
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

static func effect(key: String) -> Dictionary:
	if not EFFECTS.has(key):
		return {"label": key.capitalize(), "unit": "", "stage": "unsupported", "actions": [], "description": "Unsupported effect: preserved in the file but has no registered runtime mechanic."}
	var data: Array = EFFECTS[key]
	return {"label": data[0], "unit": data[1], "stage": data[2], "actions": data[3], "description": data[4]}

static func applies(key: String, action: int) -> bool:
	return EFFECTS.has(key) and (EFFECTS[key][3].is_empty() or action in EFFECTS[key][3])

static func record(stage: String, evidence: Dictionary) -> Dictionary:
	return {"id": stage, "label": LABELS[STAGES.find(stage)], "evidence": evidence}

static func profile(action: int) -> String:
	return ["Receive Conditioning", "Set Isolation", "Attack Transfer", "Block Deflection", "Serve Delivery"][action]
