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
# Reach cost: ratings are thresholds, not purchases, so owning a node needs the highest requirement in each Attribute along its path
# from the root, and the cost is those maxima above the base rating, summed, in AP.
const Store := preload("res://scripts/athlete_store.gd")
const PATH := "res://data/trait_tree.json"
const KINDS := ["trait", "innate", "planned"]
const SHORT := {"power": "POW", "speed": "SPD", "accuracy": "ACC", "endurance": "END"}
const COLUMN_GAP := 150.0
const ROW_GAP := 110.0

var nodes: Array = []

# The nodes the game already has, laid out in a column per page.
static func seeded() -> Array:
	var out: Array = []
	for key in Store.ATTRIBUTES:
		var previous := ""
		var row := 0
		for entry in Store.TREE[key]:
			var id := "%s_%s" % [key, String(entry.name).to_snake_case()]
			out.append({"id": id, "name": entry.name, "text": entry.text, "kind": "trait", "attribute": key, "needs": entry.needs.duplicate(), "parent": previous, "cost": 0, "pos": [0.0, row * ROW_GAP], "exclusive": ""})
			previous = id
			row += 1
		var planned: Dictionary = Store.PLANNED[key]
		out.append({"id": "%s_%s" % [key, String(planned.name).to_snake_case()], "name": planned.name, "text": planned.text, "kind": "planned", "attribute": key, "needs": {key: Store.BASE_RATING + Store.STAT_RANGE}, "parent": previous, "cost": 0, "pos": [0.0, row * ROW_GAP], "exclusive": ""})
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

func save_book(path: String = PATH) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"nodes": nodes}, "\t"))
	return true

static func _clean(raw: Dictionary) -> Dictionary:
	var needs := {}
	for key in raw.get("needs", {}):
		needs[key] = float(raw.needs[key])
	var pos: Array = raw.get("pos", [0, 0])
	return {"id": str(raw.get("id", "")), "name": str(raw.get("name", "")), "text": str(raw.get("text", "")), "kind": str(raw.get("kind", "trait")), "attribute": str(raw.get("attribute", "")), "needs": needs, "parent": str(raw.get("parent", "")), "effects": raw.get("effects",{}).duplicate(true), "cost": int(raw.get("cost", 0)), "pos": [float(pos[0]), float(pos[1])], "exclusive": str(raw.get("exclusive", ""))}

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
	var node := {"id": unique_id("new trait"), "name": "", "text": "", "kind": "trait", "attribute": attribute, "needs": {}, "parent": parent, "cost": 0, "pos": [pos.x, pos.y], "exclusive": ""}
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

func would_cycle(id: String, new_parent: String) -> bool:
	var cursor := new_parent
	var guard := 0
	while cursor != "" and guard < 1000:
		if cursor == id:
			return true
		var i := find(cursor)
		cursor = nodes[i].parent if i >= 0 else ""
		guard += 1
	return false

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
	for key in node.needs:
		if not key in Store.ATTRIBUTES:
			out.append("Unknown Attribute %s." % key)
		elif float(node.needs[key]) < Store.BASE_RATING or float(node.needs[key]) > Store.MAX_RATING + 20:
			out.append("%s minimum must be %d or more." % [SHORT[key], Store.BASE_RATING])
	if node.kind == "innate" and int(node.cost) <= 0:
		out.append("Innates need an AP cost.")
	if String(node.get("exclusive", "")) != "" and node.parent != "":
		out.append("Only the first node of a branch can be in an exclusive group.")
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

func group_of(id: String) -> String:
	var root := root_of(id)
	var i := find(root)
	return String(nodes[i].get("exclusive", "")) if i >= 0 else ""

# Two nodes lock each other out when they are in different branches of the same exclusive group.
func conflicts(a: String, b: String) -> bool:
	var group := group_of(a)
	return group != "" and group == group_of(b) and root_of(a) != root_of(b)

# The highest requirement in each Attribute along the path to a node (and the node's own).
func path_needs(id: String) -> Dictionary:
	var out := {}
	for step in path_of(id):
		var node: Dictionary = nodes[find(step)]
		for key in node.needs:
			out[key] = maxf(float(out.get(key, 0.0)), float(node.needs[key]))
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
func selection_problems(ids: Array, ap_budget: int = Store.AP_BUDGET) -> Array[String]:
	var out: Array[String] = []
	for id in ids:
		var i := find(String(id))
		if i < 0:
			out.append("Unknown node %s." % id)
			continue
		var parent: String = nodes[i].parent
		if parent != "" and not ids.has(parent):
			out.append("%s needs %s taken first." % [nodes[i].name, nodes[find(parent)].name if find(parent) >= 0 else parent])
	for a in range(ids.size()):
		for b in range(a + 1, ids.size()):
			if conflicts(String(ids[a]), String(ids[b])):
				out.append("%s and %s are in locked-out branches." % [nodes[find(String(ids[a]))].name, nodes[find(String(ids[b]))].name])
	var cost := reach_cost(ids)
	if cost > ap_budget:
		out.append("Needs %d AP; the budget is %d." % [cost, ap_budget])
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
