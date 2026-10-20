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
	check(b.capacity_used(["a", "a1", "a2", "s", "s1", "cap"]) == 3, "A capstone built on both paths takes their place: only it counts (3)")
	check(b.capacity_used(["a", "a1", "a2", "s", "s1", "free"]) == 6, "A standalone capstone adds its own weight")
	check(b.capacity_for([]) == 6 and b.capacity_for(["Deep Bag"]) == 8, "Capacity is 6, 8 with Deep Bag")
	check(b.selection_problems(["a", "a1", "a2", "s", "s1", "free"], 99, 5).size() == 1, "A build over capacity is reported")
	# The real tree and the athlete store
	Store.forget_trait_book()
	var book = Store.trait_book()
	check(int(book.rules.capacity) == 6 and int(book.rules.deep_bag_slots) == 2 and String(book.rules.forks) == "exclusive", "The saved tree carries the rules")
	var ids := {}
	for n in book.nodes:
		ids[n.name] = n.id
	check(book.weight_of(ids["Revenger"]) == 3 and book.weight_of(ids["Never Stay Down"]) == 3, "The capstones weigh 3")
	check(book.conflicts(ids["Topspin Serve"], ids["Com-Pepp-Itor"]) and book.conflicts(ids["Flow Hitter"], ids["Transition Hitter"]), "The serve and Pepper lines are alternatives, as are Flow Hitter and Transition Hitter")
	check(book.conflicts(ids["Platform Quality"], ids["Shoot Set"]) and book.conflicts(ids["Rolling Receive"], ids["Second Wind"]), "ACC and END each have one start")
	check(not book.conflicts(ids["Power Serve"], ids["Quick Step"]) and not book.conflicts(ids["Revenger"], ids["Power Serve"]), "Pages and standalone capstones do not lock each other")
	var a: Dictionary = Store.blank()
	a.power = 77.0
	a.speed = 66.0
	a.picks = []
	check(Store.pick_trait(a, ids["Power Serve"]) and Store.pick_trait(a, ids["Topspin Serve"]) == false, "Topspin Serve also needs ACC")
	a.accuracy = 70.0
	check(Store.pick_trait(a, ids["Topspin Serve"]) and Store.pick_trait(a, ids["Jump Topspin"]), "Climbs the serve line")
	check(Store.capacity_used(a) == 1, "Three picks on one path use one slot")
	check(Store.pick_blocker(a, ids["Com-Pepp-Itor"]) == "locked", "The Pepper line is locked out")
	check(Store.pick_blocker(a, ids["Quick Step"]) == "", "Another page is open")
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
	check(Store.pick_blocker(b2, ids["Platform Quality"]) == "capacity", "A third path is refused for lack of room")
	check(not Store.pick_trait(b2, ids["Platform Quality"]), "...and cannot be picked")
	b2.innates = ["Deep Bag"]
	check(Store.trait_capacity(b2) == 8 and Store.pick_trait(b2, ids["Platform Quality"]), "Deep Bag makes room")
	b2.innates = []
	Store.prune_picks(b2)
	check(Store.capacity_used(b2) <= 6 and not b2.picks.has(ids["Platform Quality"]), "Losing Deep Bag drops the newest pick")
	# Deepening a path is not breadth
	book.nodes[book.find(ids["Power Serve"])].weight = 1
	Store.forget_trait_book()
	print("trait_capacity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
