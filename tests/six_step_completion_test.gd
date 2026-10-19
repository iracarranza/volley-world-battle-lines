extends "res://tests/support/test_case.gd"
const Store := preload("res://scripts/athlete_store.gd")
const Athlete := preload("res://scripts/athlete.gd")
const Charge := preload("res://scripts/receive_charge.gd")
const Execution := preload("res://scripts/contact_execution.gd")
const Platform := preload("res://scripts/receive_platform.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var blank := Store.blank()
	for parent in Store.ATTRIBUTES:
		check(Store.STATS[parent].size() == 3 and blank.offsets[parent].size() == 3,"Three current substats per parent")
	check(Store.STATS.accuracy.has("Stability") and Store.STATS.endurance == ["Cushioning","Work Rate","Capacity"],"Latest ACC/END definitions supersede old plan")
	var old := {"power":65,"speed":65,"accuracy":65,"endurance":65,"offsets":{"power":[2,6,-8],"speed":[2,-2,0,0],"accuracy":[-3,3,0],"endurance":[5,-2,-3,0]},"name":"Legacy","picks":["power_power_serve"]}
	var converted := Store.migrate(old)
	check(converted.legacy_statistics.offsets == old.offsets,"Legacy allocation preserved losslessly in archive")
	check(not old.has("stat_version"),"Migration does not mutate source")
	check(converted.picks == old.picks and converted.name == old.name,"Identity and explicit trait ownership survive migration")
	check(converted.statistics.jump_power == 65 and converted.statistics.stability == 65 and converted.statistics.cushioning == 65,"Unrelated legacy stats are not relabelled into new effects")
	check(Store.migrate(converted) == converted,"Migration is idempotent")
	converted.offsets.power = [-2.0,0.0,2.0]
	Store.sync_statistics(converted)
	check(converted.statistics.swing_power == 67 and converted.statistics.explosiveness == 63,"Named accessors synchronize with edited offsets")
	var saved_path := Store.save_path
	var saved_roster := Store.roster
	var saved_selected := Store.selected
	Store.save_path = "user://six_step_temporary_roster.json"
	Store.roster = [converted]
	Store.selected = 0
	Store.save_roster()
	Store.load_roster()
	check(Store.selected_config().statistics.swing_power == 67,"Canonical stats survive save/load round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.save_path))
	Store.save_path = saved_path
	Store.roster = saved_roster
	Store.selected = saved_selected
	var book = preload("res://scripts/trait_book.gd").new()
	book.load_book()
	var trait_node: Dictionary = book.nodes[book.find("new_trait")]
	check(trait_node.effects.spike_velocity == 10,"Authored trait numeric effect loads")
	trait_node.effects.spike_velocity = 14
	book.save_book("user://six_step_temporary_traits.json")
	var reloaded = preload("res://scripts/trait_book.gd").new()
	reloaded.load_book("user://six_step_temporary_traits.json")
	check(reloaded.nodes[reloaded.find("new_trait")].effects.spike_velocity == 14,"Trait effect edits survive save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://six_step_temporary_traits.json"))
	var a := Athlete.new()
	a.build = Athlete.BUILDS[0].duplicate(true)
	a.build.statistics = {"swing_power":99,"cushioning":99}
	a.trait_ids = ["new_trait","power_power_serve","endurance_charge_tolerance"]
	check(is_equal_approx(a.effective_attack_charge(1),1.3),"Multiply Swing Power then add Big Hitter, uncapped")
	check(is_equal_approx(a.effective_serve_charge(1),1.12),"Power Serve adds exactly 12 percentage points")
	check(a.serve_speed_factor(1) > 1,"Serve additive changes actual speed factor")
	var attack := Charge.shot("attack",1.3,"test")
	check(attack.charge == 1.3,"Charge metadata retains >100%")
	var mismatch := Charge.match_charge(attack,1,a.cushioning_bonus())
	var tolerant := Charge.match_charge(attack,1,a.cushioning_bonus(),a.trait_effect("charge_tolerance"))
	check(not tolerant.matched and tolerant.status == "undercharged","Charge Tolerance does not manufacture matches")
	check(tolerant.severity < mismatch.severity,"Charge Tolerance softens mismatch severity")
	check(Charge.match_charge(Charge.shot("attack",1.2,"test"),1,a.cushioning_bonus()).matched,"Cushioning can match an over-100 attack")
	var prep := preload("res://scripts/bot_preparation.gd").new()
	var rng := RandomNumberGenerator.new()
	prep.begin(0,0,Charge.shot("attack",0.8,"test"),1.2,100,rng,0.2,1.0)
	check(is_equal_approx(prep.state_for(0).target,0.675),"Bot preparation accounts for its own Cushioning rather than overcharging")
	prep.tick(0,1.2)
	check(Charge.match_charge(Charge.shot("attack",0.8,"test"),prep.state_for(0).locked_charge,0.2).matched,"Bot's actual accumulated charge matches with additive Cushioning")
	a.trait_ids = ["new_trait_2"]
	a.stamina = 1
	a.spend(1)
	check(a.winded and is_equal_approx(a.stamina,a.max_stamina()*0.23),"Second Wind restores 23% of actual capacity on Winded")
	check(a.second_wind_cooldown == 30,"Second Wind has 30-second cooldown")
	a.spend(a.stamina)
	check(a.exhausted and a.stamina == 0,"Second depletion still exhausts; no repeated passive refill")
	a.recover(7,true)
	check(a.winded and a.stamina == 0 and a.second_wind_cooldown == 23,"Exhaustion returns to Winded while passive remains on cooldown")
	a.reset_fatigue()
	a.trait_ids = ["endurance_stamina_recovery"]
	a.stamina = 20
	a.recover(1,true)
	check(is_equal_approx(a.stamina,30.35),"Stamina Recovery is now a trait effect")
	a.trait_ids = ["endurance_exertion_efficiency"]
	a.stamina = 100
	a.spend(10)
	check(is_equal_approx(a.stamina,91.2),"Exertion Efficiency reduces actual action costs")
	a.trait_ids = ["endurance_fast_recovery"]
	check(is_equal_approx(a.recovery_rate(),1.12),"Recovery is an independent trait multiplier")
	var raw := {"hit":true,"quality":0.6,"sweet":false,"zone":"WEAK"}
	var outgoing := Vector3(2,5,-8)
	var ideal := Vector3(0,6,-8)
	var incoming := Vector3(0,-2,15)
	var neutral := Execution.velocity(0,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,0)
	var control := Execution.velocity(0,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,99,0)
	check(control.distance_to(ideal) < neutral.distance_to(ideal),"Ball Control improves ordinary receive fidelity independently of sweet Timing")
	var with_flow := Execution.velocity(0,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,100)
	check(with_flow.distance_to(ideal) < neutral.distance_to(ideal),"Flow improves receive effect")
	var set_base := Execution.velocity(1,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,0)
	var set_flow := Execution.velocity(1,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,100)
	check(set_flow.distance_to(outgoing) < set_base.distance_to(outgoing),"Flow improves set effect")
	check(Execution.velocity(2,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,100).length() > Execution.velocity(2,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,0).length(),"Flow improves attack effect")
	check(Execution.velocity(3,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,100).y < Execution.velocity(3,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,0).y,"Flow improves block effect")
	var strong_block := Execution.velocity(3,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,0,1.0)
	var tired_block := Execution.velocity(3,outgoing,incoming,Vector3.FORWARD,raw,65,ideal,65,0,0.8)
	check(tired_block.y > strong_block.y,"Low-Stamina availability also weakens block absorption/downward output")
	check(raw == {"hit":true,"quality":0.6,"sweet":false,"zone":"WEAK"},"Flow and stats never rewrite hurtbox zone/quality")
	var lab = load("res://main.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.moc.enabled = false
	lab.auto_feed = false
	await physics_frame
	lab.athlete.trait_ids.assign([])
	var fan: Dictionary = lab._raw_hurtbox_definition(0)
	lab.athlete.trait_ids.assign(["accuracy_platform_quality"])
	var improved: Dictionary = lab._raw_hurtbox_definition(0)
	check(fan.size == improved.size and fan.side_reach == improved.side_reach,"Platform Quality does not enlarge physical reach")
	var point := Vector3(0,fan.center.y,-fan.forward_reach*0.60)
	check(Platform.evaluate(improved,point-Vector3(improved.center)).quality > Platform.evaluate(fan,point-Vector3(fan.center)).quality,"Platform Quality increases receive-zone overlap")
	lab.athlete.trait_ids.assign([])
	lab.athlete.build.statistics = {"timing":99}
	check(lab._raw_hurtbox_definition(0) == fan,"Timing does not alter receive geometry")
	lab.athlete.trait_ids.assign(["new_trait_7"])
	lab.athlete.flow = 100
	var receive := {"id":"revenge","actor":"player","physical_hit":true,"action":0,"quality":0.2,"incoming_shot":{"kind":"attack"},"incoming_velocity":Vector3(0,-2,20),"point":lab.player.position,"charge_match":{"matched":false,"status":"undercharged","severity":1}}
	lab.contact_flow.record(receive)
	check(lab.contact_flow.pending_attacks.player == 15 and lab.athlete.jump_power_bonus == 10,"Revenger arms next attack and jump after attack receive reduces Flow")
	lab.contact_flow.consume_jump("player")
	check(lab.athlete.jump_power_bonus == 0 and lab.contact_flow.pending_attacks.player == 15,"Jump and attack bonuses consume independently")
	lab.contact_flow.consume_attack("player")
	check(not lab.contact_flow.pending_attacks.has("player"),"Attack bonus is one-shot")
	lab._reset()
	lab.athlete.build.statistics = {"swing_power":99}
	lab.athlete.trait_ids.assign(["new_trait","new_trait_3"])
	lab.athlete.flow = 100
	var effective: float = lab.contact_flow.attack_charge(0.6,"player")
	check(is_equal_approx(effective,1.02),"Flow Hitter is additive after Swing Power and Big Hitter")
	lab._shot_velocity(Vector3(0,3,4),2,0.6)
	check(lab.athlete.flow == 100,"Aiming/preview cannot consume Flow")
	lab.ball_active = true
	lab.locked_action = 2
	lab.selected = 2
	lab.locked_charge = 0.6
	lab.armed = true
	var spike: Dictionary = lab._raw_hurtbox_definition(2)
	lab.ball.position = lab.player.position+Vector3(spike.center)+lab.Geometry.sector_point(spike,0.74,67.5,0)
	lab.ball_velocity = incoming
	lab._confirm_action()
	lab.confirm_window = lab.confirm_duration-0.22
	lab._contact()
	check(is_equal_approx(lab.last_contact_result.outgoing_shot.charge,effective),"Real attack metadata uses identical effective charge")
	check(lab.athlete.flow <= 25,"Real Flow Hitter consumes old Flow, then new contact earns Flow")
	lab.athlete.trait_ids.assign(["endurance_fast_recovery"])
	lab.athlete.build.statistics = {"transition_speed":65}
	lab.animation.floor_recovery_name = "knee"
	lab.animation.floor_recovery_time = 0
	lab.animation.floor_recovery_lock = 0.4
	lab.animation.tick_floor_recovery(0.1)
	check(is_equal_approx(lab.animation.floor_recovery_time,0.112),"Recovery trait drives actual recovery controller")
	lab.queue_free()
	await process_frame
	print("SIX STEP COMPLETION: %d / %d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
