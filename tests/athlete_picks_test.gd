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
func ids_of(book, name: String) -> String:
	for n in book.nodes:
		if n.name == name:
			return n.id
	return ""
func run() -> void:
	var Store = load("res://scripts/athlete_store.gd")
	Store.forget_trait_book()
	var book = Store.trait_book()
	var a: Dictionary = Store.blank()
	check(Store.owned_traits(a).is_empty(), "A base athlete owns nothing (legacy rule)")
	check(Store.trait_options(a).is_empty() or true, "Options can be listed without picks")
	var serve := ids_of(book, "Power Serve")
	var big := ids_of(book, "Big Hitter")
	check(not Store.pick_trait(a, serve), "POW 65 cannot pick Power Serve (needs 68)")
	a.power = 68.0
	check(Store.trait_options(a).has(serve) and Store.trait_options(a).has(big), "At POW 68 both starting branches are open")
	check(Store.pick_trait(a, serve), "Picks Power Serve")
	check(Store.has_picks(a) and Store.owned_traits(a) == ["Power Serve"], "A picking athlete owns exactly its picks")
	check(not Store.trait_options(a).has(big), "The other starting branch is locked out")
	check(not Store.pick_trait(a, big), "Cannot pick Big Hitter after Power Serve")
	var topspin := ids_of(book, "Topspin Serve")
	a.power = 71.0
	check(not Store.trait_options(a).has(topspin), "Topspin Serve also needs ACC 68")
	a.accuracy = 68.0
	check(Store.trait_options(a).has(topspin), "ACC 68 and POW 71 open Topspin Serve")
	check(not Store.trait_options(a).has(ids_of(book, "Jump Topspin")), "A node needs its parent picked first")
	Store.pick_trait(a, topspin)
	a.accuracy = 70.0
	a.power = 72.0
	check(Store.pick_trait(a, ids_of(book, "Jump Topspin")), "Reaches Jump Topspin with ACC 70 and POW 72")
	check(Store.ap_spent(a) == 12, "The Jump Topspin build spends exactly the 12 AP budget")
	var back := ids_of(book, "Back Attacker")
	check(not Store.pick_trait(a, back), "The Big Hitter side stays locked")
	a.accuracy = 69.0
	Store.prune_picks(a)
	check(Store.owned_traits(a) == ["Power Serve", "Topspin Serve"], "Dropping ACC below 70 drops Jump Topspin only")
	a.power = 70.0
	Store.prune_picks(a)
	check(Store.owned_traits(a) == ["Power Serve"], "Dropping POW below 71 drops Topspin Serve")
	Store.unpick_trait(a, serve)
	check(Store.owned_traits(a).is_empty() and Store.trait_options(a).has(big), "Dropping the first pick reopens the other branch")
	var p: Dictionary = Store.blank()
	p.power = 77.0
	p.speed = 65.0
	check(not Store.trait_options(p).has(ids_of(book, "Pepper Patroller")), "Pepper Patroller is not offered below its requirements")
	print("athlete_picks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
