extends RefCounted
## MS-05 characterization support: consequence ledger snapshots, the dual-run comparator and golden-trace files.
## Test support only. Nothing here writes gameplay state; it reads a LabSession and records what it sees.
## Regenerate golden traces with tests/golden/README.md (run the dump script directly with `-- --regen`).
const EPS := 1e-9
const GOLDEN_DIR := "res://tests/golden/"

## JSON-safe, comparable copy of any value (Vector3 to arrays, floats snapped to the comparator tolerance, objects by class).
static func norm(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT: return snappedf(value, 1e-10) if is_finite(value) else str(value)
		TYPE_INT, TYPE_BOOL, TYPE_STRING, TYPE_NIL: return value
		TYPE_STRING_NAME: return str(value)
		TYPE_VECTOR3: return [norm(value.x), norm(value.y), norm(value.z)]
		TYPE_VECTOR2: return [norm(value.x), norm(value.y)]
		TYPE_COLOR: return value.to_html()
		TYPE_DICTIONARY:
			var out := {}
			var keys: Array = value.keys()
			keys.sort_custom(func(a, b): return str(a) < str(b))
			for key in keys:
				out[str(key)] = norm(value[key])
			return out
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var list := []
			for item in value:
				list.append(norm(item))
			return list
		TYPE_OBJECT: return "<%s>" % (value.get_class() if value != null else "null")
		_: return str(value)

## The consequence ledger line: observable state a stage may not change (blueprint 3.2). Read-only.
static func snapshot(lab: Node) -> Dictionary:
	var athlete = lab.athlete
	var flow = lab.contact_flow
	var bots = lab.training_bots
	var pepper = lab.pepper
	var moc = lab.moc
	var shot: Dictionary = lab.ball_shot
	return norm({
		"ball": {"position": lab.ball.position, "velocity": lab.ball_velocity, "active": lab.ball_active,
			"shot_kind": shot.get("kind", ""), "shot_actor": shot.get("actor", ""), "shot_charge": shot.get("charge", -1.0)},
		"player": {"stamina": athlete.stamina, "hp": athlete.hp, "flow_field": athlete.flow, "winded": athlete.winded,
			"exhausted": athlete.exhausted, "epoch": athlete.fatigue_epoch},
		"flow": {"values": flow.values, "last_changes": flow.last_changes, "pending_attacks": flow.pending_attacks.keys(),
			"epochs": flow.fatigue_epochs},
		"rally": {"contacts": lab.contacts, "side_contacts": lab.side_contacts, "last_touch_side": lab.rally_rules.last_touch_side,
			"bot_contacts": bots.total_contacts, "bot_last_action": bots.last_action, "bot_last_was_block": bots.last_was_block,
			"pepper_player_contacts": pepper.player_contacts, "pepper_exchanges": pepper.exchanges},
		"locks": {"roll_lock": lab.animation.roll_lock, "endlag": lab.action_endlag, "armed": lab.armed},
		"moc": {"active": moc.active, "ball_scale": moc.simulation_scale(), "player_scale": moc.actor_scale("player"), "events": moc.event_count},
	})

## Path-listed differences between two normalized values. Empty means equal (floats within `tolerance`).
static func diff(a: Variant, b: Variant, path: String = "", tolerance: float = EPS) -> Array:
	var out: Array = []
	_diff(a, b, path, tolerance, out)
	return out

static func _diff(a: Variant, b: Variant, path: String, tolerance: float, out: Array) -> void:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		if absf(float(a) - float(b)) > tolerance: out.append("%s: %s != %s" % [path, a, b])
		return
	if ta != tb:
		out.append("%s: type %s != %s (%s vs %s)" % [path, ta, tb, a, b])
		return
	if ta == TYPE_DICTIONARY:
		for key in a.keys():
			if not b.has(key): out.append("%s/%s: missing in second" % [path, key])
			else: _diff(a[key], b[key], path + "/" + str(key), tolerance, out)
		for key in b.keys():
			if not a.has(key): out.append("%s/%s: missing in first" % [path, key])
	elif ta == TYPE_ARRAY:
		if a.size() != b.size():
			out.append("%s: length %d != %d" % [path, a.size(), b.size()])
			return
		for index in range(a.size()):
			_diff(a[index], b[index], "%s[%d]" % [path, index], tolerance, out)
	elif a != b:
		out.append("%s: %s != %s" % [path, a, b])

static func regen_requested() -> bool:
	return "--regen" in OS.get_cmdline_user_args()

static func golden_path(name: String) -> String:
	return GOLDEN_DIR + name + ".json"

static func load_golden(name: String) -> Variant:
	var path := golden_path(name)
	if not FileAccess.file_exists(path): return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func save_golden(name: String, trace: Variant) -> bool:
	var file := FileAccess.open(golden_path(name), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(trace, "\t", true) + "\n")
	return true

## A fresh session for a scenario. The MoC clock is injected so slowdown windows do not depend on wall time.
static func new_lab(tree: SceneTree, scene: String = "res://main.tscn") -> Node:
	var lab = load(scene).instantiate()
	tree.root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	await tree.physics_frame
	var clock := [1000000]
	lab.moc.clock = func(): return clock[0]
	lab.set_meta("clock", clock)
	return lab

static func advance_clock(lab: Node, microseconds: int) -> void:
	lab.get_meta("clock")[0] += microseconds

static func free_lab(tree: SceneTree, lab: Node) -> void:
	lab.queue_free()
	await tree.process_frame
