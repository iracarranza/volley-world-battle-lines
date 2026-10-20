extends RefCounted

# The trait tree as editable data. Each Trait lives on the page of its primary Attribute; other Attributes it
# needs show up as an "Also Requires" tag instead of a second node. Saved to res://data/trait_tree.json.
#
# node: {id, name, text, kind: "trait"|"innate"|"planned", attribute, needs{attr: min}, parent: id or "", cost, pos [x, y], exclusive}
#
# Branches: a node with no parent starts a branch. Roots that share the same non-empty `exclusive` name are alternatives: choosing
# a trait in one locks every other branch in the group, and a branch is its root plus everything below it. Nodes below the root
# connect freely. A node with no parent and no `exclusive` is standalone (a capstone, say) and is never locked.
#
# Three different relationships between nodes (decided 2026-10-19):
#   parent    the node advances its parent's line. It consumes the parent: only the successor applies effects and takes capacity,
#             and the two are one branch of the parent's fork.
#   requires  the node needs another node owned, from any page, without advancing it. The required node keeps its own capacity and its own
#             effects, and takes part in no fork of the requiring node. Used for hybrids (Hybrid Server) and advanced Traits.
#   needs     attribute ratings, independent of both.
# A node's position says nothing about its tier: a node with no parent is introductory only if it is a starting choice; an advanced node can
# have no parent and rest on `requires` and `needs` alone.
#
# Capacity: an athlete's build holds `rules.capacity` points, plus `rules.deep_bag_slots` with the Deep Bag innate. Only the frontier counts:
# a picked node that no other picked node has as its parent. Its `weight` (1 to 3) is what it costs. Forks are exclusive while rules.forks is
# "exclusive": of the children of one node only one branch can be taken. Each starting node (no parent, no `requires`) opens a subtree of its own;
# with rules.starts "free" an athlete may open as many as capacity allows (a hitter takes the hitting and serving subtrees together), and with
# "exclusive" only one per page. `standalone` marks an advanced parentless node. An explicit `exclusive` group on parentless nodes stays exclusive.
#
# node adds: weight (1..3), requires [ids], alt_parents [ids], standalone (an advanced node that is not a starting choice),
# carried {parent id: effects} (what a node with several parents keeps from the one it consumes), needs_stats {effect: total} (a stat the
# build must already have from its current Traits, for example Spin), flow (the node is a Flow effect)
#
# Successors do not inherit (decided 2026-10-19): a node that builds on another consumes it, and only current Traits apply. So a successor's
# `effects` and text are written as running totals; a node with several parents carries a different total from each (`carried`).
#
# A node reachable from several alternative lines (Rhythm Hitter, from Big Hitter or Tough Arms) lists its first line in `parent`
# and the others in `alt_parents`: any one is enough, and `via` selects which owned parent it consumes.
# `merges` lists every source of a node that requires and consumes them all (Trickster, from Broad Range ACC and Anticipation).
#
# Reach cost: ratings are thresholds, not purchases, so owning a node needs the highest requirement in each Attribute along its path
# from the root, and the cost is those maxima above the base rating, summed, in AP.
const Store := preload("res://scripts/athlete_store.gd")
const PATH := "res://data/trait_tree.json"
const KINDS := ["trait", "innate", "planned"]
const SHORT := {"power": "POW", "speed": "SPD", "accuracy": "ACC", "endurance": "END"}
const COLUMN_GAP := 150.0
const ROW_GAP := 110.0

var nodes: Array = []
var rules := {"capacity": 6, "deep_bag_slots": 2, "forks": "exclusive", "starts": "free", "flow_effects": 1, "open_mind_flow": 2}

# The nodes the game already has, laid out in a column per page.
static func seeded() -> Array:
	var out: Array = []
	for key in Store.ATTRIBUTES:
		var previous := ""
		var row := 0
		for entry in Store.TREE[key]:
			var id := "%s_%s" % [key, String(entry.name).to_snake_case()]
			out.append({"id": id, "name": entry.name, "text": entry.text, "kind": "trait", "attribute": key, "needs": entry.needs.duplicate(), "parent": previous, "cost": 0, "pos": [0.0, row * ROW_GAP], "exclusive": "", "weight": 1, "requires": [], "alt_parents": [], "standalone": false, "carried": {}, "needs_stats": {}, "flow": false})
			previous = id
			row += 1
		var planned: Dictionary = Store.PLANNED.get(key, {})
		if not planned.is_empty():
			out.append({"id": "%s_%s" % [key, String(planned.name).to_snake_case()], "name": planned.name, "text": planned.text, "kind": "planned", "attribute": key, "needs": {key: Store.BASE_RATING + Store.STAT_RANGE}, "parent": previous, "cost": 0, "pos": [0.0, row * ROW_GAP], "exclusive": "", "weight": 1, "requires": [], "alt_parents": [], "standalone": false, "carried": {}, "needs_stats": {}, "flow": false})
	return out

func load_book(path: String = PATH) -> void:
	nodes = seeded()
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("nodes") is Array:
		nodes = []
		for raw in parsed.nodes:
			nodes.append(_clean(raw))
		if parsed.get("rules") is Dictionary:
			for key in parsed.rules:
				rules[key] = parsed.rules[key]

func save_book(path: String = PATH) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"nodes": nodes, "rules": rules}, "\t"))
	return true

static func _strings(value) -> Array:
	var out := []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out

static func _numbers(value) -> Dictionary:
	var out := {}
	if value is Dictionary:
		for key in value:
			out[str(key)] = float(value[key])
	return out

# What the gameplay runtime accepts (docs/gameplay-runtime-contract.md). Anything else in a rule is flagged, not silently dropped.
const GAMEPLAY_TRIGGERS := ["receive", "set", "attack", "block", "jump", "attack_receive_flow_loss", "inflicted_recovery", "low_stamina", "ally_attack_charge"]
const GAMEPLAY_KEYS := ["explosiveness", "jump_power", "swing_power", "acceleration", "reaction_speed", "transition_speed", "ball_control", "timing", "stability", "cushioning", "work_rate", "capacity", "power", "speed", "accuracy", "endurance", "explosiveness_band", "jump_power_band", "swing_power_band", "explosiveness_band_cap", "jump_power_band_cap", "swing_power_band_cap", "spike_velocity", "serve_velocity", "receive_charge_bonus", "back_attack_velocity", "platform_quality", "broad_range", "vertical_reach", "court_vision", "receive_control", "receive_absorption", "receive_redirection", "charge_tolerance", "recovery", "stamina_recovery", "exertion_efficiency", "stride_speed", "flow_state", "placement", "ally_attack_charge_tolerance", "mismatch_knockback", "mismatch_stamina_drain", "transition_speed_penalty", "inflicted_recovery_duration", "charge_aim_variance", "di_stamina_cost", "di_hp_cost", "di_cost_reduction", "flow_attack_velocity", "revenge_spike_velocity", "revenge_jump_power", "second_wind", "jump_stamina_threshold"]

static func _rules(value) -> Array:
	var out := []
	if value is Array:
		for rule in value:
			if rule is Dictionary:
				out.append(rule.duplicate(true))
	return out

static func _effects_by(value) -> Dictionary:
	var out := {}
	if value is Dictionary:
		for parent in value:
			out[str(parent)] = _numbers(value[parent])
	return out

static func _clean(raw: Dictionary) -> Dictionary:
	var needs := {}
	for key in raw.get("needs", {}):
		needs[key] = float(raw.needs[key])
	var pos: Array = raw.get("pos", [0, 0])
	return {"id": str(raw.get("id", "")), "name": str(raw.get("name", "")), "text": str(raw.get("text", "")), "kind": str(raw.get("kind", "trait")), "attribute": str(raw.get("attribute", "")), "needs": needs, "parent": str(raw.get("parent", "")), "effects": raw.get("effects",{}).duplicate(true), "cost": int(raw.get("cost", 0)), "pos": [float(pos[0]), float(pos[1])], "exclusive": str(raw.get("exclusive", "")), "weight": clampi(int(raw.get("weight", 1)), 1, 3), "requires": _strings(raw.get("requires", [])), "alt_parents": _strings(raw.get("alt_parents", [])), "merges": _strings(raw.get("merges", [])), "needs_subs": _numbers(raw.get("needs_subs", {})), "gameplay": _rules(raw.get("gameplay", [])), "carried": _effects_by(raw.get("carried", {})), "needs_stats": _numbers(raw.get("needs_stats", {})), "flow": bool(raw.get("flow", false)), "standalone": bool(raw.get("standalone", false))}

func find(id: String) -> int:
	for i in range(nodes.size()):
		if nodes[i].id == id:
			return i
	return -1

func page(attribute: String) -> Array:
	return nodes.filter(func(n): return n.attribute == attribute)

func unique_id(name: String) -> String:
	var base := name.to_snake_case() if not name.strip_edges().is_empty() else "node"
	var id := base
	var n := 2
	while find(id) >= 0:
		id = "%s_%d" % [base, n]
		n += 1
	return id

# A blank node on a page, optionally hanging off a parent. It starts invalid on purpose until it is filled in.
func add_node(attribute: String, pos: Vector2, parent: String = "") -> Dictionary:
	var node := {"id": unique_id("new trait"), "name": "", "text": "", "kind": "trait", "attribute": attribute, "needs": {}, "parent": parent, "cost": 0, "pos": [pos.x, pos.y], "exclusive": "", "weight": 1, "requires": [], "alt_parents": [], "standalone": false, "carried": {}, "needs_stats": {}, "flow": false}
	nodes.append(node)
	return node

func remove_node(id: String) -> void:
	var index := find(id)
	if index < 0:
		return
	var removed: Dictionary = nodes[index]
	nodes.remove_at(index)
	for n in nodes:
		if n.parent == id:
			n.parent = removed.parent   # children move up to the removed node's parent, or become standalone
		if n.get("requires", []).has(id):
			n.requires.erase(id)
		if n.get("alt_parents", []).has(id):
			n.alt_parents.erase(id)
		if n.get("merges", []).has(id):
			n.merges.erase(id)
		if n.get("carried", {}).has(id):
			n.carried.erase(id)

func would_cycle(id: String, new_parent: String) -> bool:
	return new_parent != "" and (new_parent == id or ancestry(new_parent).has(id))

# Problems that stop a node being valid. Empty means fine.
func problems(node: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if String(node.name).strip_edges().is_empty():
		out.append("Needs a name.")
	else:
		for other in nodes:
			if other.id != node.id and String(other.name).strip_edges().to_lower() == String(node.name).strip_edges().to_lower():
				out.append("Name is already used by another node.")
				break
	if String(node.text).strip_edges().is_empty():
		out.append("Needs a description.")
	if node.needs.is_empty():
		out.append("Needs at least one Attribute restriction.")
	elif not node.needs.has(node.attribute):
		out.append("Primary Attribute (%s) must be one of its requirements." % SHORT.get(node.attribute, "?"))
	var seen_ids := []
	for rule in node.get("gameplay", []):
		var rid := String(rule.get("id", ""))
		if rid == "":
			out.append("A gameplay rule needs an id.")
		elif seen_ids.has(rid):
			out.append("Gameplay rule id %s is repeated on this node." % rid)
		seen_ids.append(rid)
		if not GAMEPLAY_TRIGGERS.has(String(rule.get("trigger", ""))):
			out.append("Gameplay rule %s has an unknown trigger." % rid)
		var blocks: Array = [rule.get("effects", {})]
		for slot in rule.get("pending", {}):
			blocks.append(rule.pending[slot])
		for block in blocks:
			if not block is Dictionary:
				out.append("Gameplay rule %s has a malformed effects block." % rid)
				continue
			for key in block:
				if not GAMEPLAY_KEYS.has(String(key)):
					out.append("Gameplay rule %s uses %s, which the runtime does not claim." % [rid, key])
	for key in node.get("needs_subs", {}):
		if Store.sub_parent(String(key)) == "":
			out.append("Unknown sub-attribute %s." % key)
	for key in node.needs:
		if not key in Store.ATTRIBUTES:
			out.append("Unknown Attribute %s." % key)
		elif float(node.needs[key]) < Store.BASE_RATING or float(node.needs[key]) > Store.MAX_RATING + 20:
			out.append("%s minimum must be %d or more." % [SHORT[key], Store.BASE_RATING])
	if node.kind == "innate" and int(node.cost) <= 0:
		out.append("Innates need an AP cost.")
	if String(node.get("exclusive", "")) != "" and node.parent != "":
		out.append("Only the first node of a branch can be in an exclusive group.")
	var weight := int(node.get("weight", 1))
	if weight < 1 or weight > 3:
		out.append("Capacity weight must be 1 to 3.")
	for other in node.get("alt_parents", []):
		if find(String(other)) < 0:
			out.append("An alternative parent no longer exists.")
		elif String(other) == String(node.id) or ancestry(String(other)).has(String(node.id)):
			out.append("An alternative parent makes a loop.")
	for other in node.get("merges", []):
		if find(String(other)) < 0:
			out.append("A merged node no longer exists.")
		elif String(other) == String(node.id) or ancestry(String(other)).has(String(node.id)):
			out.append("A merged node makes a loop.")
	for required in node.get("requires", []):
		if find(String(required)) < 0:
			out.append("A required node no longer exists.")
		elif String(required) == String(node.id) or ancestry(String(required)).has(String(node.id)):
			out.append("Requirement makes a loop.")
	if node.parent != "":
		var parent_index := find(node.parent)
		if parent_index < 0:
			out.append("Parent no longer exists.")
		elif nodes[parent_index].attribute != node.attribute:
			out.append("Parent is on a different page.")
		elif would_cycle(node.id, node.parent):
			out.append("Parent link makes a loop.")
	return out

func all_problems() -> Dictionary:
	var out := {}
	for n in nodes:
		var found := problems(n)
		if not found.is_empty():
			out[n.id] = found
	return out

# "Also Requires: SPD 70, END 68" for every need that is not the primary Attribute, or "" if there is none.
func also_requires(node: Dictionary) -> String:
	var parts: Array[String] = []
	for key in Store.ATTRIBUTES:
		if key != node.attribute and node.needs.has(key):
			parts.append("%s %d" % [SHORT[key], int(node.needs[key])])
	return "" if parts.is_empty() else "Also Requires: " + ", ".join(parts)

func requirement_text(node: Dictionary) -> String:
	var primary := "%s %d" % [SHORT.get(node.attribute, "?"), int(node.needs.get(node.attribute, 0))]
	var also := also_requires(node)
	return primary if also.is_empty() else primary + "  /  " + also

# --- Branches and reach cost -----------------------------------------------------------------

func root_of(id: String) -> String:
	var cursor := id
	var guard := 0
	while guard < 1000:
		var i := find(cursor)
		if i < 0 or nodes[i].parent == "" or find(nodes[i].parent) < 0:
			return cursor
		cursor = nodes[i].parent
		guard += 1
	return cursor

# The node and its ancestors, nearest first.
func path_of(id: String) -> Array:
	var out := []
	var cursor := id
	var guard := 0
	while cursor != "" and find(cursor) >= 0 and guard < 1000:
		out.append(cursor)
		cursor = nodes[find(cursor)].parent
		guard += 1
	return out

# Every parent of a node: its first parent and the alternatives.
func parents_of(id: String) -> Array:
	var i := find(id)
	var out := []
	if i < 0:
		return out
	var node: Dictionary = nodes[i]
	var first: String = String(node.get("parent", ""))
	if first != "" and find(first) >= 0:
		out.append(first)
	for other in node.get("alt_parents", []):
		if find(String(other)) >= 0 and not out.has(String(other)):
			out.append(String(other))
	for other in node.get("merges", []):
		if find(String(other)) >= 0 and not out.has(String(other)):
			out.append(String(other))
	return out

# The nodes a node merges: it needs every one of them taken, and claiming it consumes them all into one Trait.
func merges_of(id: String) -> Array:
	var i := find(id)
	var out := []
	if i < 0:
		return out
	for other in nodes[i].get("merges", []):
		if find(String(other)) >= 0 and not out.has(String(other)):
			out.append(String(other))
	return out

# The parents a player picks between (any one will do): everything but the merged ones.
func choice_parents(id: String) -> Array:
	var merged := merges_of(id)
	var out := []
	for parent in parents_of(id):
		if not merged.has(parent):
			out.append(parent)
	return out

# Everything a node can stand on: itself, all its parents and requirements, recursively.
func ancestry(id: String) -> Array:
	var out := []
	var queue := [id]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		if out.has(current) or find(current) < 0:
			continue
		out.append(current)
		for parent in parents_of(current):
			queue.append(parent)
		for required in nodes[find(current)].get("requires", []):
			queue.append(String(required))
	return out

# The same through parents only: the lines a node advances, which is where forks apply.
func lineage(id: String) -> Array:
	var out := []
	var queue := [id]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		if out.has(current) or find(current) < 0:
			continue
		out.append(current)
		for parent in parents_of(current):
			queue.append(parent)
	return out

# All direct prerequisites, flat: the parents (any one will do) and the requirements (all needed).
func prereqs(id: String) -> Array:
	var out := parents_of(id)
	for required in nodes[find(id)].get("requires", []):
		if find(String(required)) >= 0 and not out.has(String(required)):
			out.append(String(required))
	return out

# What is still missing for a node to be taken with these picks: a line to build on (any parent) and every requirement, as names.
func unmet(id: String, picks: Array) -> Array:
	var out := []
	var parents := choice_parents(id)
	if not parents.is_empty():
		var have := false
		for parent in parents:
			if picks.has(parent):
				have = true
		if not have:
			var names := []
			for parent in parents:
				names.append(String(nodes[find(parent)].name))
			out.append(" or ".join(names))
	for merged in merges_of(id):
		if not picks.has(merged):
			out.append(String(nodes[find(merged)].name))
	for required in nodes[find(id)].get("requires", []):
		if find(String(required)) >= 0 and not picks.has(String(required)):
			out.append(String(nodes[find(String(required))].name))
	return out

func group_of(id: String) -> String:
	var root := root_of(id)
	var i := find(root)
	return String(nodes[i].get("exclusive", "")) if i >= 0 else ""

# The start group a parentless node belongs to, or "": its explicit group, else its page when starts are exclusive. Forks between children are
# handled in conflicts().
func start_key(node: Dictionary) -> String:
	if not parents_of(String(node.id)).is_empty():
		return ""
	if String(node.get("exclusive", "")) != "":
		return "group:" + String(node.exclusive)
	if String(rules.get("forks", "exclusive")) != "exclusive" or bool(node.get("standalone", false)):
		return ""
	if node.get("requires", []).is_empty() and String(rules.get("starts", "free")) == "exclusive":
		return "page:" + String(node.attribute)
	return ""

# Two nodes lock each other out when they sit under different branches of one exclusive fork: children of one parent (a node listing several
# parents is a child of each), or start choices of one group.
func conflicts(a: String, b: String) -> bool:
	var below_a := lineage(a)
	var below_b := lineage(b)
	var forks_on := String(rules.get("forks", "exclusive")) == "exclusive"
	for x in below_a:
		var node_x: Dictionary = nodes[find(x)]
		for y in below_b:
			if x == y or below_b.has(x) or below_a.has(y):
				continue
			var node_y: Dictionary = nodes[find(y)]
			if forks_on and not bool(node_x.get("standalone", false)) and not bool(node_y.get("standalone", false)):
				for parent in parents_of(x):
					if parents_of(y).has(parent):
						return true
			var key := start_key(node_x)
			if key != "" and key == start_key(node_y):
				return true
	return false

# The parents a node stands on in a particular build, for fork exclusivity: a picked node uses the parent it consumed; the candidate (not yet
# picked) uses the one side being tested; any other node uses all of its parents.
func _route_parents(x: String, picks: Array, via: Dictionary, candidate: String, side: String) -> Array:
	if x == candidate and side != "":
		return [side]
	if picks.has(x):
		return consumed_parents(x, picks, via)
	return parents_of(x)

func _route_lineage(id: String, picks: Array, via: Dictionary, candidate: String, side: String) -> Array:
	var out := []
	var queue := [id]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		if out.has(current) or find(current) < 0:
			continue
		out.append(current)
		for parent in _route_parents(current, picks, via, candidate, side):
			queue.append(parent)
	return out

# Does taking `candidate` (through `side`, one of its parents, or "" for none) fork against a node already picked in this build? A node that
# can be reached from two lines only uses the fork of the line it was actually taken through.
func conflicts_route(candidate: String, other: String, picks: Array, via: Dictionary, side: String) -> bool:
	var below_a := _route_lineage(candidate, picks, via, candidate, side)
	var below_b := _route_lineage(other, picks, via, candidate, side)
	var forks_on := String(rules.get("forks", "exclusive")) == "exclusive"
	for x in below_a:
		var node_x: Dictionary = nodes[find(x)]
		for y in below_b:
			if x == y or below_b.has(x) or below_a.has(y):
				continue
			var node_y: Dictionary = nodes[find(y)]
			if forks_on and not bool(node_x.get("standalone", false)) and not bool(node_y.get("standalone", false)):
				var parents_y := _route_parents(y, picks, via, candidate, side)
				for parent in _route_parents(x, picks, via, candidate, side):
					if parents_y.has(parent):
						return true
			var key := start_key(node_x)
			if key != "" and key == start_key(node_y):
				return true
	return false

# Is `candidate` locked out by what is picked? Only if every way of taking it (each parent it could be taken through) forks against a pick.
func locked_in_build(candidate: String, picks: Array, via: Dictionary, chosen_side: String = "") -> bool:
	var sides: Array = [chosen_side] if chosen_side != "" else choice_parents(candidate)
	if sides.is_empty():
		sides = [""]
	for side in sides:
		var clear := true
		for picked in picks:
			if conflicts_route(candidate, String(picked), picks, via, String(side)):
				clear = false
				break
		if clear:
			return false
	return true

static func _ap(needs: Dictionary) -> float:
	var total := 0.0
	for key in needs:
		total += maxf(0.0, float(needs[key]) - Store.BASE_RATING)
	return total

static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for key in b:
		out[key] = maxf(float(out.get(key, 0.0)), float(b[key]))
	return out

# The ratings needed to take a node by the cheapest route: its own, its requirements' and, of its parents, the cheapest line to it.
func path_needs(id: String, guard: Array = []) -> Dictionary:
	var i := find(id)
	if i < 0 or guard.has(id):
		return {}
	var trail := guard.duplicate()
	trail.append(id)
	var out: Dictionary = nodes[i].needs.duplicate()
	for required in nodes[i].get("requires", []):
		out = _merge(out, path_needs(String(required), trail))
	for merged in merges_of(id):
		out = _merge(out, path_needs(merged, trail))
	var best := {}
	var best_cost := INF
	for parent in choice_parents(id):
		var through := _merge(out, path_needs(parent, trail))
		var cost := _ap(through)
		if cost < best_cost:
			best_cost = cost
			best = through
	return best if best_cost < INF else out

# Sub-attribute ratings needed to take a node, given what is picked: its own, its requirements', its merged nodes' and the picked parents'.
func subs_given(id: String, picks: Array, guard: Array = []) -> Dictionary:
	var i := find(id)
	if i < 0 or guard.has(id):
		return {}
	var trail := guard.duplicate()
	trail.append(id)
	var out: Dictionary = nodes[i].get("needs_subs", {}).duplicate()
	var sources: Array = (nodes[i].get("requires", []) as Array) + merges_of(id)
	for parent in choice_parents(id):
		if picks.has(parent):
			sources.append(parent)
	for source in sources:
		out = _merge(out, subs_given(String(source), picks, trail))
	return out

# The same for display, with no picks: the first line to the node.
func path_subs(id: String, guard: Array = []) -> Dictionary:
	var i := find(id)
	if i < 0 or guard.has(id):
		return {}
	var trail := guard.duplicate()
	trail.append(id)
	var out: Dictionary = nodes[i].get("needs_subs", {}).duplicate()
	var sources: Array = (nodes[i].get("requires", []) as Array) + merges_of(id)
	var choices := choice_parents(id)
	if not choices.is_empty():
		sources.append(choices[0])
	for source in sources:
		out = _merge(out, path_subs(String(source), trail))
	return out

# The ratings needed to take a node given what is already picked: its own, its requirements', and every picked parent's; with no parent
# picked yet, the cheapest line to it.
func needs_given(id: String, picks: Array, guard: Array = []) -> Dictionary:
	var i := find(id)
	if i < 0 or guard.has(id):
		return {}
	var trail := guard.duplicate()
	trail.append(id)
	var out: Dictionary = nodes[i].needs.duplicate()
	for required in nodes[i].get("requires", []):
		out = _merge(out, needs_given(String(required), picks, trail))
	for merged in merges_of(id):
		out = _merge(out, needs_given(merged, picks, trail))
	var picked_parents := []
	for parent in choice_parents(id):
		if picks.has(parent):
			picked_parents.append(parent)
	if picked_parents.is_empty():
		var best := {}
		var best_cost := INF
		for parent in choice_parents(id):
			var through := _merge(out, needs_given(parent, picks, trail))
			if _ap(through) < best_cost:
				best_cost = _ap(through)
				best = through
		return best if best_cost < INF else out
	for parent in picked_parents:
		out = _merge(out, needs_given(String(parent), picks, trail))
	return out

# AP above the base rating to reach the given nodes together: the highest need per Attribute over all of them, summed.
func reach_cost(ids: Array) -> int:
	var highest := {}
	for id in ids:
		var needs := path_needs(String(id))
		for key in needs:
			highest[key] = maxf(float(highest.get(key, 0.0)), float(needs[key]))
	var total := 0.0
	for key in highest:
		total += maxf(0.0, float(highest[key]) - Store.BASE_RATING)
	return int(total)

func reachable_at_base(id: String, ap_budget: int = Store.AP_BUDGET) -> bool:
	return reach_cost([id]) <= ap_budget

# Problems with a set of picked nodes: a parent not picked, two locked-out branches, or more AP than the budget.
func selection_problems(ids: Array, ap_budget: int = Store.AP_BUDGET, capacity: int = -1) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		var i := find(String(id))
		if i < 0:
			out.append("Unknown node %s." % id)
			continue
		for missing in unmet(String(id), ids):
			out.append("%s needs %s taken first." % [nodes[i].name, missing])
	for a in range(ids.size()):
		for b in range(a + 1, ids.size()):
			if conflicts(String(ids[a]), String(ids[b])):
				out.append("%s and %s are in locked-out branches." % [nodes[find(String(ids[a]))].name, nodes[find(String(ids[b]))].name])
	var cost := reach_cost(ids)
	if cost > ap_budget:
		out.append("Needs %d AP; the budget is %d." % [cost, ap_budget])
	if capacity >= 0 and capacity_used(ids) > capacity:
		out.append("Uses %d capacity; the limit is %d." % [capacity_used(ids), capacity])
	return out

# Exclusive groups and the branch roots in each.
func groups() -> Dictionary:
	var out := {}
	for n in nodes:
		var group := String(n.get("exclusive", ""))
		if group != "" and n.parent == "":
			if not out.has(group):
				out[group] = []
			out[group].append(n.id)
	return out

# Notes that are not errors: a group with a single branch locks nothing.
func warnings(node: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var group := String(node.get("exclusive", ""))
	if group != "" and groups().get(group, []).size() < 2:
		out.append("Group \"%s\" has only one branch, so it locks nothing." % group)
	return out

# --- Capacity -----------------------------------------------------------------------------------

# The parents of a node that taking it consumes: its only parent, or of several the one chosen (`via`, falling back to the first taken).
func consumed_parents(id: String, picks: Array, via: Dictionary = {}) -> Array:
	var merged := merges_of(id)
	if not merged.is_empty():
		for other in merged:
			if not picks.has(other):
				return []
		return merged
	var parents := parents_of(id)
	var taken := []
	for parent in parents:
		if picks.has(parent):
			taken.append(parent)
	if parents.size() <= 1 or taken.size() <= 1:
		return taken
	var chosen := String(via.get(id, ""))
	return [chosen] if taken.has(chosen) else [taken[0]]

# The picked nodes that nothing else has consumed: the build's current Traits. Only these apply and only these cost capacity.
func frontier(picks: Array, via: Dictionary = {}) -> Array:
	# Resolve each picked node's consumption once, rather than repeating the
	# same parent walks for every candidate. Keep the original pick order below.
	var consumed := {}
	var known := {}
	for id in picks:
		if find(String(id)) < 0:
			continue
		known[String(id)] = true
		for parent in consumed_parents(String(id), picks, via):
			if String(parent) != String(id):
				consumed[String(parent)] = true
	var out := []
	for id in picks:
		if known.has(String(id)) and not consumed.has(String(id)):
			out.append(String(id))
	return out

# The effects a build has: each current Trait's own, plus what it carries from the parent it consumed.
func active_effects(picks: Array, via: Dictionary = {}) -> Dictionary:
	var total := {}
	for id in frontier(picks, via):
		var node: Dictionary = nodes[find(String(id))]
		for key in node.get("effects", {}):
			total[key] = float(total.get(key, 0.0)) + float(node.effects[key])
		# What it kept from where it came from: `carried` is keyed by any node it consumed, directly or down the line (a successor of Rhythm Hitter
		# keeps Big Hitter's bonus or Tough Arms' according to which Rhythm Hitter consumed).
		for source in consumed_sources(String(id), picks, via):
			for key in node.get("carried", {}).get(source, {}):
				total[key] = float(total.get(key, 0.0)) + float(node.carried[source][key])
	return total

# The structured runtime rules a build has: each current Trait's own, as the contract asks (consumed predecessors contribute nothing).
# A repeated rule id keeps the first, so a build never carries two rules under one id.
func active_gameplay_rules(picks: Array, via: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := []
	for id in frontier(picks, via):
		for rule in nodes[find(String(id))].get("gameplay", []):
			var rid := String(rule.get("id", ""))
			if rid == "" or seen.has(rid):
				continue
			seen.append(rid)
			out.append(rule.duplicate(true))
	return out

# Every node this one consumed, directly or through what it consumed.
func consumed_sources(id: String, picks: Array, via: Dictionary = {}) -> Array:
	var out := []
	var queue := consumed_parents(id, picks, via)
	while not queue.is_empty():
		var current: String = String(queue.pop_back())
		if out.has(current):
			continue
		out.append(current)
		for parent in consumed_parents(current, picks, via):
			queue.append(parent)
	return out

# The unmet stat requirements of a node for these picks, as "Spin 8" strings.
func unmet_stats(id: String, picks: Array, via: Dictionary = {}) -> Array:
	var out := []
	var needs: Dictionary = nodes[find(id)].get("needs_stats", {})
	if needs.is_empty():
		return out
	var have := active_effects(picks, via)
	for key in needs:
		if float(have.get(key, 0.0)) < float(needs[key]):
			out.append("%s %d" % [String(key).capitalize(), int(needs[key])])
	return out

func flow_count(picks: Array, via: Dictionary = {}) -> int:
	var count := 0
	for id in frontier(picks, via):
		if bool(nodes[find(String(id))].get("flow", false)):
			count += 1
	return count

func flow_limit_for(innates: Array) -> int:
	return int(rules.get("flow_effects", 1)) + (int(rules.get("open_mind_flow", 2)) if "Open Mind" in innates else 0)

func weight_of(id: String) -> int:
	var i := find(id)
	return clampi(int(nodes[i].get("weight", 1)), 1, 3) if i >= 0 else 0

func capacity_used(picks: Array, via: Dictionary = {}) -> int:
	var total := 0
	for id in frontier(picks, via):
		total += weight_of(String(id))
	return total

# Capacity for an athlete with these innates.
func capacity_for(innates: Array) -> int:
	return int(rules.get("capacity", 6)) + (int(rules.get("deep_bag_slots", 2)) if "Deep Bag" in innates else 0)
