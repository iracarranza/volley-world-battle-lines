extends SceneTree
var checks := 0
var failures := 0
func check(c: bool, m: String) -> void:
	checks += 1
	if not c:
		failures += 1
		push_error(m)
func _initialize() -> void:
	call_deferred("run")
func node(id: String, attribute: String, parent: String, need: float, weight := 1, requires := [], standalone := false) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "text": "x", "kind": "trait", "attribute": attribute, "needs": {attribute: need}, "parent": parent, "cost": 0, "pos": [0, 0], "exclusive": "", "weight": weight, "requires": requires, "standalone": standalone, "effects": {}}
func run() -> void:
	var Book = load("res://scripts/trait_book.gd")
	var Store = load("res://scripts/athlete_store.gd")
	var b = Book.new()
	b.rules.starts = "exclusive"
	b.nodes = [
		node("a", "power", "", 68), node("a1", "power", "a", 70), node("a2", "power", "a1", 72, 2),
		node("b", "power", "", 68), node("a1x", "power", "a", 71),
		node("s", "speed", "", 68), node("s1", "speed", "s", 70), node("s1b", "speed", "s", 71),
		node("cap", "power", "", 80, 3, ["a2", "s1"]), node("free", "power", "", 80, 3, [], true),
	]
	# Forks
	check(b.conflicts("a1", "a1x"), "Children of one node are exclusive: only one branch")
	check(b.conflicts("a2", "a1x"), "...including everything below them")
	check(not b.conflicts("a", "a1") and not b.conflicts("a1", "a2"), "A path is not in conflict with itself")
	check(b.conflicts("a", "b"), "Roots on a page are exclusive: one start")
	check(not b.conflicts("a", "s") and not b.conflicts("a1", "s1"), "Different pages do not lock each other")
	check(not b.conflicts("free", "a") and not b.conflicts("free", "b"), "A standalone node is outside the start choice")
	check(not b.conflicts("cap", "a"), "A node with requirements is not a root")
	b.rules.forks = "open"
	check(not b.conflicts("a1", "a1x") and not b.conflicts("a", "b"), "With forks open, nothing locks")
	b.rules.forks = "exclusive"
	# Requirements
	check(b.prereqs("cap") == ["a2", "s1"] if false else b.prereqs("cap").has("a2") and b.prereqs("cap").has("s1") and b.prereqs("cap").size() == 2, "A node's prerequisites are its parent and its requirements")
	check(b.ancestry("cap").has("a") and b.ancestry("cap").has("s"), "Ancestry follows requirements across pages")
	var needs: Dictionary = b.path_needs("cap")
	check(float(needs.power) == 80.0 and float(needs.speed) == 70.0, "Reach counts what every required node needs: POW 80, SPD 70 (%s)" % str(needs))
	check(b.would_cycle("a", "cap"), "A requirement loop is caught")
	check(not b.selection_problems(["a", "a1", "a2", "s", "s1", "cap"], 99, 99).is_empty() == false, "A capstone is fine with all its prerequisites")
	check(not b.selection_problems(["a", "a1", "a2", "cap"], 99, 99).is_empty(), "...and not without one of them")
	# Frontier and weight
	check(b.frontier(["a", "a1", "a2"]) == ["a2"], "Only the deepest node of a path is the current Trait")
	check(b.capacity_used(["a", "a1", "a2"]) == 2, "Its weight is what it costs (2)")
	check(b.capacity_used(["a", "a1", "a2", "s", "s1"]) == 3, "Two paths, two current Traits: 2 + 1")
	check(b.capacity_used(["a", "a1", "a2", "s", "s1", "cap"]) == 6, "A node that only requires paths does not absorb them: 2 + 1 + 3 = 6")
	check(b.frontier(["a", "a1", "a2", "s", "s1", "cap"]).size() == 3, "The required nodes stay current Traits")
	check(not b.conflicts("cap", "a1x") and not b.conflicts("cap", "b"), "A requiring node takes no fork from the nodes it requires")
	check(b.capacity_used(["a", "a1"]) == 1 and b.capacity_used(["a", "a1x"]) == 1, "A child incorporates its parent: one slot")
	check(b.capacity_used(["a", "a1", "a2", "s", "s1", "free"]) == 6, "A standalone capstone adds its own weight")
	check(b.capacity_for([]) == 6 and b.capacity_for(["Deep Bag"]) == 8, "Capacity is 6, 8 with Deep Bag")
	check(b.selection_problems(["a", "a1", "a2", "s", "s1", "free"], 99, 5).size() == 1, "A build over capacity is reported")
	# Alternative parents: reachable from more than one line
	var c = Book.new()
	c.rules.starts = "free"
	var shared := node("flow", "power", "big", 72)
	shared["alt_parents"] = ["tough"]
	c.nodes = [node("big", "power", "", 68), node("tough", "power", "", 66), shared, node("scr", "power", "tough", 68), node("heavy", "power", "flow", 76)]
	c.nodes[1].needs = {"power": 66.0, "speed": 68.0}
	check(c.parents_of("flow") == ["big", "tough"], "A node lists its parent and its alternatives")
	check(c.unmet("flow", []).size() == 1 and c.unmet("flow", ["tough"]).is_empty() and c.unmet("flow", ["big"]).is_empty(), "Any one parent is enough")
	check(c.frontier(["big", "flow"]) == ["flow"] and c.frontier(["tough", "flow"]) == ["flow"], "Either way, the shared node builds on the parent taken")
	check(c.frontier(["big", "tough", "flow"]).size() == 2 and c.frontier(["big", "tough", "flow"]).has("tough"), "With both starters taken it consumes only one: the other keeps its slot (first by default)")
	check(c.frontier(["big", "tough", "flow"], {"flow": "tough"}).has("big") and not c.frontier(["big", "tough", "flow"], {"flow": "tough"}).has("tough"), "...or the one chosen")
	check(c.conflicts("flow", "scr") and not c.conflicts("big", "scr"), "As a child of Tough Arms it is the other branch from Scramble")
	check(float(c.path_needs("flow").get("speed", 0.0)) == 0.0 and c.reach_cost(["flow"]) == 7, "Its reach is the cheapest route: through Big Hitter, no speed")
	var given: Dictionary = c.needs_given("flow", ["tough"])
	check(float(given.get("speed", 0.0)) == 68.0, "Taken through Tough Arms, the ratings Tough Arms needed count")
	check(float(c.needs_given("flow", ["big"]).get("speed", 0.0)) == 0.0, "Taken through Big Hitter they do not")
	check(c.selection_problems(["flow", "heavy"], 99, 99).size() == 1, "A build with no parent of Rhythm Hitter is refused")
	check(c.selection_problems(["tough", "flow", "heavy"], 99, 99).is_empty(), "...and fine with one")
	Store.forget_trait_book()
	# The real tree and the athlete store
	Store.forget_trait_book()
	var book = Store.trait_book()
	check(int(book.rules.capacity) == 6 and int(book.rules.deep_bag_slots) == 2 and String(book.rules.forks) == "exclusive", "The saved tree carries the rules")
	var ids := {}
	for n in book.nodes:
		ids[n.name] = n.id
	check(book.weight_of(ids["Terminal Hitter"]) == 3 and book.weight_of(ids["Never Stay Down"]) == 3 and book.weight_of(ids["Power Serve"]) == 1, "The most demanding legendaries weigh 3, starters 1")
	check(book.conflicts(ids["Topspin Serve"], ids["Rattling Serve"]) and book.conflicts(ids["Heavy Arm"], ids["Spring Legs"]), "The serve and Pepper lines are alternatives, as are Heavy Arm and Spring Legs")
	check(not book.conflicts(ids["Terminal Hitter"], ids["Topspin Serve"]) and not book.conflicts(ids["Big Hitter"], ids["Scramble"]), "Different subtrees can be held together")
	check(not book.conflicts(ids["Steady Arms"], ids["Shoot Set"]) and not book.conflicts(ids["Rolling Receive"], ids["Second Wind"]), "Starts are free: subtrees open side by side, capacity limits them")
	check(not book.conflicts(ids["Power Serve"], ids["Big Hitter"]) and not book.conflicts(ids["Power Serve"], ids["Quick Step"]), "A hitter can open the serving and hitting subtrees together")
	check(book.parents_of(ids["Rhythm Hitter"]).has(ids["Big Hitter"]) and book.parents_of(ids["Rhythm Hitter"]).has(ids["Tough Arms"]), "Rhythm Hitter is reachable from Big Hitter and Tough Arms")
	check(book.parents_of(ids["Never Stay Down"]) == [ids["Apex Hitter"]] and book.conflicts(ids["Rhythm Hitter"], ids["Heavy Arm"]) and book.conflicts(ids["Rhythm Hitter"], ids["Spring Legs"]) and book.conflicts(ids["Jungle Ball"], ids["Rhythm Hitter"]), "Rhythm Hitter, Heavy Arm and Spring Legs are alternatives under Big Hitter, and Tough Arms chooses Rhythm Hitter or Scramble")
	var both: Dictionary = Store.blank()
	both.power = 80.0
	both.speed = 70.0
	both.picks = []
	check(Store.pick_trait(both, ids["Big Hitter"]) and Store.pick_trait(both, ids["Tough Arms"]) and Store.pick_trait(both, ids["Rhythm Hitter"]), "Rhythm Hitter is open to a build with both starters")
	Store.unpick_trait(both, ids["Big Hitter"])
	check(both.picks.has(ids["Rhythm Hitter"]) and both.picks.has(ids["Tough Arms"]), "Dropping one starter keeps Rhythm Hitter while the other is taken")
	Store.unpick_trait(both, ids["Tough Arms"])
	check(not both.picks.has(ids["Rhythm Hitter"]), "...and loses it when neither is")
	var via_hitter: Dictionary = Store.blank()
	via_hitter.power = 72.0
	via_hitter.picks = []
	check(Store.pick_trait(via_hitter, ids["Big Hitter"]) and Store.pick_trait(via_hitter, ids["Rhythm Hitter"]), "A pure POW build reaches Rhythm Hitter through Big Hitter without any SPD")
	var a: Dictionary = Store.blank()
	a.power = 77.0
	a.speed = 66.0
	a.picks = []
	check(Store.pick_trait(a, ids["Power Serve"]) and Store.pick_trait(a, ids["Topspin Serve"]) == false, "Topspin Serve also needs ACC")
	a.accuracy = 70.0
	check(Store.pick_trait(a, ids["Topspin Serve"]) and Store.pick_trait(a, ids["Jump Topspin"]), "Climbs the serve line")
	check(Store.capacity_used(a) == 1, "Three picks on one path use one slot")
	check(Store.pick_blocker(a, ids["Rattling Serve"]) == "locked", "The Pepper line is locked out")
	check(Store.pick_blocker(a, ids["Quick Step"]) == "", "Another page is open")
	# Successors do not inherit: only current Traits apply, with running totals
	var topspin_build := ["power_power_serve", "new_trait_5"]
	check(is_equal_approx(float(book.active_effects(topspin_build).get("serve_velocity", 0.0)), 18.0), "A successor's running total is what applies: Topspin Serve is +18, not 12 + 18")
	check(book.frontier(topspin_build) == ["new_trait_5"], "Power Serve is consumed")
	var via_big: Dictionary = book.active_effects(["new_trait", "new_trait_3"])
	check(float(via_big.get("spike_velocity", 0.0)) == 10.0 and not via_big.has("platform_quality"), "Rhythm Hitter taken through Big Hitter keeps Big Hitter's +10 Spike Velocity")
	var tough_via := {"new_trait_3": "pow_tough_arms"}
	var via_tough: Dictionary = book.active_effects(["new_trait", "pow_tough_arms", "new_trait_3"], tough_via)
	check(float(via_tough.get("platform_quality", 0.0)) == 4.0 and float(via_tough.get("spike_velocity", 0.0)) == 10.0, "Consuming Tough Arms keeps its +4 Platform Quality, and Big Hitter stays a current Trait with its +10")
	var deep: Dictionary = book.active_effects(["new_trait", "pow_heavy_arm", "pow_sledgehammer"])
	check(float(deep.get("spike_velocity", 0.0)) == 15.0 and book.frontier(["new_trait", "pow_heavy_arm", "pow_sledgehammer"]) == ["pow_sledgehammer"], "A successor is a running total: Sledgehammer is +15, restating Big Hitter's 10")
	check(book.active_gameplay_rules(["new_trait", "pow_heavy_arm", "pow_sledgehammer"]).is_empty() and book.active_gameplay_rules(["new_trait", "pow_spring_legs", "pow_skyhook", "pow_apex_hitter", "new_trait_11"]).is_empty(), "The Heavy Arm and Spring Legs lines use no Flow mechanics")
	# Stat requirements: Tooler needs 8 Spin from current Traits
	check(not book.unmet_stats("pow_tooler", ["new_trait", "pow_wide_arm", "pow_edge_contact"]).is_empty(), "Tooler needs Spin: Edge Contact alone is 4")
	check(book.unmet_stats("pow_tooler", ["new_trait", "pow_wide_arm", "pow_edge_contact", "pow_eyes_up", "pow_read_the_block"]).is_empty(), "Edge Contact and Read the Block together give the 8 Spin")
	var tooler: Dictionary = Store.blank()
	for key in ["power", "accuracy"]:
		tooler[key] = 80.0
	tooler.picks = []
	for step in ["new_trait", "pow_wide_arm", "pow_edge_contact", "pow_eyes_up"]:
		Store.pick_trait(tooler, ids[book.nodes[book.find(step)].name])
	check(Store.pick_blocker(tooler, "pow_tooler") != "" and Store.pick_blocker(tooler, "pow_read_the_block") == "", "Tooler is refused until the Spin is there")
	Store.pick_trait(tooler, "pow_read_the_block")
	check(Store.pick_blocker(tooler, "pow_tooler") == "" or Store.pick_blocker(tooler, "pow_tooler") == "capacity", "...and not for lack of Spin once it is (%s)" % Store.pick_blocker(tooler, "pow_tooler"))
	# One Flow effect per build, three with Open Mind
	var flowing: Dictionary = Store.blank()
	for key in ["power", "speed", "accuracy", "endurance"]:
		flowing[key] = 90.0
	flowing.picks = []
	var line := ["power_power_serve", "new_trait", "new_trait_3", "pow_utility_arm", "pow_stand_tall", "pow_jackknife", "new_trait_7"]
	for step in line:
		Store.pick_trait(flowing, step)
	check(flowing.picks.has("new_trait_3") and not flowing.picks.has("new_trait_7"), "A second Flow effect (Revenger) is refused beside Rhythm Hitter")
	check(Store.pick_blocker(flowing, "new_trait_7") == "flow", "...for the Flow limit")
	flowing.innates = ["Open Mind"]
	check(Store.flow_limit(flowing) == 3 and Store.pick_blocker(flowing, "new_trait_7") == "", "Open Mind raises it to three")
	# The athlete: a consumed Trait no longer applies
	var athlete = load("res://scripts/athlete.gd").new()
	athlete.trait_ids.assign(["power_power_serve", "new_trait_5"])
	check(not athlete.has_trait("power_power_serve") and athlete.has_trait("new_trait_5") and is_equal_approx(athlete.trait_effect("serve_velocity"), 18.0), "In play only the successor applies")
	# Capacity fills up
	var b2: Dictionary = Store.blank()
	b2.picks = []
	for key in ["power", "speed", "accuracy", "endurance"]:
		b2[key] = 77.0
	# Make weights heavy to fill the build: 4 current Traits of weight 2 and 3
	book.nodes[book.find(ids["Power Serve"])].weight = 3
	book.nodes[book.find(ids["Quick Step"])].weight = 3
	check(Store.pick_trait(b2, ids["Power Serve"]) and Store.pick_trait(b2, ids["Quick Step"]), "Two weight 3 Traits fill a 6 slot build")
	check(Store.capacity_used(b2) == 6, "Six of six")
	check(Store.pick_blocker(b2, ids["Steady Arms"]) == "capacity", "A third path is refused for lack of room")
	check(not Store.pick_trait(b2, ids["Steady Arms"]), "...and cannot be picked")
	b2.innates = ["Deep Bag"]
	check(Store.trait_capacity(b2) == 8 and Store.pick_trait(b2, ids["Steady Arms"]), "Deep Bag makes room")
	b2.innates = []
	Store.prune_picks(b2)
	check(Store.capacity_used(b2) <= 6 and not b2.picks.has(ids["Steady Arms"]), "Losing Deep Bag drops the newest pick")
	# Deepening a path is not breadth
	book.nodes[book.find(ids["Power Serve"])].weight = 1
	Store.forget_trait_book()
	print("trait_capacity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
