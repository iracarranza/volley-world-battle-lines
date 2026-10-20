extends RefCounted

# Shared roster state between the title screen, athlete menu and the lab.
# Attributes follow the handoff: four Attributes (POW/SPD/ACC/END), each governing
# underlying statistics that can be redistributed within a limited range.
static var save_path := "user://athletes.json"
const ATTRIBUTES := ["power", "speed", "accuracy", "endurance"]
const ATTRIBUTE_NAMES := {"power": "Power", "speed": "Speed", "accuracy": "Accuracy", "endurance": "Endurance"}
const BASE_RATING := 65
const MAX_RATING := 77
const AP_BUDGET := 12
const STAT_RANGE := 8
const ROLES := ["OH", "OP", "S", "MB", "L"]
const STAT_VERSION := 3
const STATS := {
 "power":["Explosiveness","Jump Power","Swing Power"],
 "speed":["Acceleration","Reaction Speed","Transition Speed"],
 "accuracy":["Ball Control","Timing","Stability"],
 "endurance":["Cushioning","Work Rate","Capacity"],
}
const LEGACY_STATS := {
	"power": ["Jump Explosiveness", "Hitting Force", "Upper-Body Strength"],
	"speed": ["Acceleration", "Max Speed", "Agility", "Reaction Speed"],
	"accuracy": ["Contact Precision", "Ball Control", "Targeting Precision"],
	"endurance": ["Stamina Capacity", "Stamina Recovery", "Exertion Efficiency", "Impact Resistance"],
}
# Four top-level Attribute nodes lead toward introductory Traits. Names come from the design
# notes; the numeric requirements are provisional (Quick Step SPD 66 and a high early ACC
# gate for Shoot Set are the only ones the notes suggest).
const TREE := {
	"power": [{"name": "Power Serve", "text": "Serve with extra force at the Net", "needs": {"power": 68}}],
	"speed": [{"name": "Quick Step", "text": "Active: double-tap a direction while an action is charged for one burst of movement. Cooldown 5s exploring, 8s in a rally.", "needs": {"speed": 66}}],
	"accuracy": [{"name": "Shoot Set", "text": "Faster, flatter set for an immediate attack", "needs": {"accuracy": 72}}],
	"endurance": [{"name": "Rolling Receive", "text": "Dive receive that rolls out, cheaper recovery", "needs": {"endurance": 68}}],
}
# Innates are match-start only and cost Base Athlete AP (costs provisional).
const INNATES := {
	"Giant": {"cost": 10, "text": "Unlocks the Giant height range (6'9\" to 7'2\"): more reach and jump height, slower to turn and recover. The height itself is covered by this cost."},
	"Tiny": {"cost": 10, "text": "Unlocks the Tiny height range (5'0\" to 5'5\"): small contact envelope, quicker direction changes, lower exertion. The height itself is covered by this cost."},
	"Workhorse": {"cost": 8, "text": "Very large base Stamina for sustained drilling and repeated effort."},
	"Deep Bag": {"cost": 6, "text": "Higher HP Minimum and two more slots of build capacity."},
	"Open Mind": {"cost": 6, "text": "A build may hold up to three Flow effects instead of one. (Provisional cost.)"},
}
const POSITION_INNATES := {
	"MB": {"name": "Wall", "text": "Minimal HP cost on Blocks; faster Block Jump charge. +2 END growth."},
	"OP": {"name": "Fast Study", "text": "Gains AP more effectively: +3 free AP on level-up."},
	"OH": {"name": "All-Rounder", "text": "Broader growth: +1 to every Attribute on level-up."},
	"S": {"name": "Playmaker", "text": "Minimal HP cost on Sets, including aim adjustment. +2 ACC growth."},
	"L": {"name": "Anchor", "text": "Minimal HP and Stamina cost on Receives. +2 SPD growth."},
}

# Planned deeper Traits (names from the design notes, not implemented yet).
const PLANNED := {
	"power": {"name": "Tool", "text": "Planned: attack that uses the blocker's hands."},
	"accuracy": {"name": "Back Set", "text": "Planned: concealed set behind the setter."},
	"endurance": {"name": "Pancake", "text": "Planned: floor-sliding save."},
}

# Heights are discrete feet/inches. 6'0\"-6'2\" is free; nearby heights cost AP; the Tiny and
# Giant ranges are only selectable with the matching Innate (their cost already covers height).
const MIN_INCHES := 60
const MAX_INCHES := 86
const FREE_MIN := 72
const FREE_MAX := 74
const TINY_MAX := 65
const GIANT_MIN := 81
const DEFAULT_INCHES := 73

static func height_inches(meters: float) -> int:
	return clampi(roundi(meters / 0.0254), MIN_INCHES, MAX_INCHES)

static func height_label(inches: int) -> String:
	return "%d'%d\"" % [inches / 12, inches % 12]

static func height_zone(inches: int) -> String:
	if inches <= TINY_MAX:
		return "tiny"
	if inches >= GIANT_MIN:
		return "giant"
	return "free" if inches >= FREE_MIN and inches <= FREE_MAX else "extended"

static func height_cost(inches: int) -> int:
	if height_zone(inches) != "extended":
		return 0
	var outside := FREE_MIN - inches if inches < FREE_MIN else inches - FREE_MAX
	return ceili(outside / 3.0)

static func height_allowed(inches: int, innates: Array) -> bool:
	var zone := height_zone(inches)
	return (zone != "tiny" or "Tiny" in innates) and (zone != "giant" or "Giant" in innates)

static var roster: Array = []
static var selected := -1

static func blank() -> Dictionary:
	var athlete := {"innates": [], "name": "Rookie", "body_type": "Feli", "appearance": {"palette_index": 0, "marking": "none"}, "role": "OH", "dominant_hand": "Right", "height": DEFAULT_INCHES * 0.0254, "span": 1.90, "level": 1}
	var offsets := {}
	for key in ATTRIBUTES:
		athlete[key] = float(BASE_RATING)
		var zeros: Array = []
		zeros.resize(STATS[key].size())
		zeros.fill(0)
		offsets[key] = zeros
	athlete["offsets"] = offsets
	athlete["stat_version"] = STAT_VERSION
	athlete["stat_names"] = STATS.duplicate(true)
	sync_statistics(athlete)
	return athlete

# Preserve the complete old allocation for inspection; only equivalent names migrate.
static func migrate(config: Dictionary) -> Dictionary:
	var out := config.duplicate(true)
	var current := int(out.get("stat_version",0)) >= STAT_VERSION
	var old_offsets: Dictionary = out.get("offsets",{})
	var previous_names := STATS.duplicate(true)
	previous_names.speed = ["Acceleration","Lateral Speed","Transition Speed"]
	var old_names: Dictionary = out.get("stat_names",STATS if current else (previous_names if int(out.get("stat_version",0)) == 2 else LEGACY_STATS))
	var named: Dictionary = out.get("statistics",{})
	if not current and not out.has("legacy_statistics"):
		out["legacy_statistics"] = {"offsets":old_offsets.duplicate(true),"names":old_names.duplicate(true),"statistics":named.duplicate(true)}
	var equivalent := {"jump_explosiveness":"explosiveness","stamina_capacity":"capacity"}
	var resolved := {}
	for parent in ATTRIBUTES:
		out[parent] = clampf(float(out.get(parent,BASE_RATING)),50,99)
		var labels: Array = old_names.get(parent,[])
		var offsets: Array = old_offsets.get(parent,[])
		for i in range(mini(labels.size(),offsets.size())):
			var key := str(labels[i]).to_snake_case()
			key = equivalent.get(key,key)
			resolved[key] = float(out[parent])+float(offsets[i])
	for key in named:
		var canonical: String = equivalent.get(str(key).to_snake_case(),str(key).to_snake_case())
		# Named values are canonical; offsets are an editor projection.
		resolved[canonical] = float(named[key])
	out.offsets = {}
	for parent in ATTRIBUTES:
		out.offsets[parent] = []
		for label in STATS[parent]:
			out.offsets[parent].append(clampf(float(resolved.get(str(label).to_snake_case(),out[parent])),50,99)-float(out[parent]))
	# If removed legacy stats supplied the balancing negatives, their positive
	# counterparts cannot become free SP. Preserve the archive and reset that
	# group for a clean respec instead of assigning debt to unrelated new stats.
	if int(out.get("stat_version",0)) < 2:
		for parent in ATTRIBUTES:
			var total := 0.0
			for value in out.offsets[parent]:
				total += float(value)
			var explicit := false
			for label in STATS[parent]:
				explicit = explicit or named.has(str(label).to_snake_case())
			if total > 0.001 and not explicit:
				out.offsets[parent].fill(0.0)
	# Lateral Speed allocations cannot be relabelled into an unrelated mechanic.
	if old_names.get("speed",[]).has("Lateral Speed") and not named.has("reaction_speed"):
		var retired: Dictionary = out.get("retired_statistics",{}).duplicate(true)
		retired["pre_reaction_speed"] = {"statistics":named.duplicate(true),"offsets":old_offsets.duplicate(true),"names":old_names.duplicate(true)}
		out["retired_statistics"] = retired
		out.offsets.speed.fill(0.0)
	out["stat_names"] = STATS.duplicate(true)
	out["stat_version"] = STAT_VERSION
	sync_statistics(out)
	return out

static func sync_statistics(config: Dictionary) -> void:
	config["statistics"] = {}
	config["stat_names"] = STATS.duplicate(true)
	config["stat_version"] = STAT_VERSION
	for parent in ATTRIBUTES:
		var offsets: Array = config.get("offsets",{}).get(parent,[])
		for i in range(STATS[parent].size()):
			config.statistics[str(STATS[parent][i]).to_snake_case()] = clampf(float(config.get(parent,65))+(float(offsets[i]) if i < offsets.size() else 0),50,99)

static func ap_spent(athlete: Dictionary) -> int:
	var spent := 0
	for key in ATTRIBUTES:
		spent += maxi(0, int(athlete[key]) - BASE_RATING)
	spent += height_cost(height_inches(float(athlete.get("height", 1.86))))
	for innate in athlete.get("innates", []):
		spent += int(INNATES.get(innate, {}).get("cost", 0))
	return spent

static func grade(rating: float) -> String:
	var bands := [[97, "A+"], [93, "A"], [90, "A-"], [87, "B+"], [83, "B"], [80, "B-"], [77, "C+"], [73, "C"], [70, "C-"], [67, "D+"], [63, "D"], [60, "D-"]]
	for band in bands:
		if rating >= band[0]:
			return band[1]
	return "F"

# The authored trait tree (data/trait_tree.json), loaded on first use. Loaded by path at run time because the book itself
# preloads this file.
static var _book = null

static func trait_book():
	if _book == null:
		_book = load("res://scripts/trait_book.gd").new()
		_book.load_book()
	return _book

static func forget_trait_book() -> void:
	_book = null

# Whether an athlete's ratings meet everything on the path to a node.
static func meets_path(config: Dictionary, id: String) -> bool:
	var needs: Dictionary = trait_book().needs_given(id, config.get("picks", []))
	for key in needs:
		if float(config.get(key, 0.0)) < float(needs[key]):
			return false
	return true

# Athletes with a "picks" list (node ids) own exactly the traits they picked; athletes without one keep the old rule of
# owning every trait whose requirements are met, so existing athletes and tests behave as before.
static func has_picks(config: Dictionary) -> bool:
	return config.has("picks")

# Capacity a build has: the tree's base plus the Deep Bag innate's slots.
static func trait_capacity(config: Dictionary) -> int:
	return trait_book().capacity_for(config.get("innates", []))

static func capacity_used(config: Dictionary) -> int:
	return trait_book().capacity_used(config.get("picks", []), config.get("via", {}))

static func flow_limit(config: Dictionary) -> int:
	return trait_book().flow_limit_for(config.get("innates", []))

# Why a node cannot be picked now, or "" if it can: "planned", "ratings", "needs" (a prerequisite not taken), "locked" (an exclusive fork
# already went the other way) or "capacity" (the build is full).
static func pick_blocker(config: Dictionary, id: String, via: String = "") -> String:
	var book = trait_book()
	var picks: Array = config.get("picks", [])
	var i: int = book.find(id)
	if i < 0 or book.nodes[i].kind == "planned" or not book.problems(book.nodes[i]).is_empty():
		return "planned"
	if picks.has(id):
		return "picked"
	for picked in picks:
		if book.conflicts(id, String(picked)):
			return "locked"
	if not meets_path(config, id):
		return "ratings"
	if not book.unmet(id, picks).is_empty():
		return "needs"
	var trial := picks.duplicate()
	trial.append(id)
	var trial_via: Dictionary = config.get("via", {}).duplicate()
	if via != "":
		trial_via[id] = via
	if not book.unmet_stats(id, picks, config.get("via", {})).is_empty():
		return "stats"
	if book.capacity_used(trial, trial_via) > trait_capacity(config):
		return "capacity"
	if bool(book.nodes[i].get("flow", false)) and book.flow_count(trial, trial_via) > flow_limit(config):
		return "flow"
	return ""

# Nodes the athlete could pick now: requirements met along the path, every prerequisite taken, not locked out by an exclusive fork already
# chosen, and room for it. Planned nodes cannot be picked.
static func trait_options(config: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for node in trait_book().nodes:
		if pick_blocker(config, node.id) == "":
			out.append(node.id)
	return out

# The nodes a legacy athlete (no picks list) already owned, as picks, so they keep their traits when first opened for editing.
static func legacy_picks(config: Dictionary) -> Array:
	var owned := owned_traits(config)
	var trial := config.duplicate(true)
	trial["picks"] = []
	for node in trait_book().nodes:
		if node.kind != "planned" and owned.has(node.name):
			pick_trait(trial, node.id)
	return trial.picks

# `via` is the parent a node with several parents consumes (the half the player clicked); "" takes the first one taken.
static func pick_trait(config: Dictionary, id: String, via: String = "") -> bool:
	if not config.has("picks"):
		config["picks"] = []
	if pick_blocker(config, id, via) != "":
		return false
	config.picks.append(id)
	if via != "" and trait_book().choice_parents(id).size() > 1:
		if not config.has("via"):
			config["via"] = {}
		config.via[id] = via
	return true

# Dropping a pick drops everything that can no longer stand without it: a node with another parent still taken stays.
static func unpick_trait(config: Dictionary, id: String) -> void:
	var book = trait_book()
	var keep: Array = []
	for picked in config.get("picks", []):
		if String(picked) != id:
			keep.append(picked)
	var changed := true
	while changed:
		changed = false
		for picked in keep:
			if not book.unmet(String(picked), keep).is_empty():
				keep.erase(picked)
				changed = true
				break
	config["picks"] = keep
	var via: Dictionary = config.get("via", {})
	for key in via.keys():
		if not keep.has(key):
			via.erase(key)

# After ratings change: drop picks whose requirements are no longer met (and what hangs from them).
static func prune_picks(config: Dictionary) -> void:
	if not config.has("picks"):
		return
	var changed := true
	while changed:
		changed = false
		for picked in config.picks:
			if not meets_path(config, String(picked)):
				unpick_trait(config, String(picked))
				changed = true
				break
	# Over capacity (Deep Bag dropped, or a node's weight raised): the newest picks go first, with whatever is built on them.
	while capacity_used(config) > trait_capacity(config) and not config.picks.is_empty():
		unpick_trait(config, String(config.picks[config.picks.size() - 1]))

# Provisional rule: a Trait is owned once its Attribute requirements are met, unless the athlete has chosen picks.
static func owned_trait_ids(config: Dictionary) -> Array[String]:
	if has_picks(config):
		var chosen: Array[String] = []
		var book = trait_book()
		for picked in config.picks:
			var i: int = book.find(String(picked))
			if i >= 0 and meets_path(config, String(picked)):
				chosen.append(String(book.nodes[i].id))
		return chosen
	var owned: Array[String] = []
	for key in ATTRIBUTES:
		for entry in TREE[key]:
			var met := true
			for need in entry.needs:
				if float(config.get(need, 0.0)) < float(entry.needs[need]):
					met = false
			if met:
				owned.append("%s_%s" % [key, String(entry.name).to_snake_case()])
	return owned

# Display labels only. Gameplay must use owned_trait_ids().
static func owned_traits(config: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var book = trait_book()
	for id in owned_trait_ids(config):
		var index: int = book.find(id)
		if index >= 0:
			names.append(str(book.nodes[index].name))
	return names

static func selected_config() -> Dictionary:
	if selected < 0 or selected >= roster.size():
		return {}
	return migrate(roster[selected])

static func load_roster() -> void:
	roster = []
	selected = -1
	if not FileAccess.file_exists(save_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		for entry in parsed.get("athletes", []):
			if entry is Dictionary:
				roster.append(migrate(entry))
		selected = int(parsed.get("selected", -1))
		if selected >= roster.size():
			selected = -1

static func save_roster() -> void:
	for index in range(roster.size()):
		roster[index] = migrate(roster[index])
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"athletes": roster, "selected": selected}))
