class_name VolleyballPlayer
extends Resource

const AttributeRegistry := preload("res://vendor/vwm/construction/scripts/domain/attribute_registry.gd")
const RoleProfiles := preload("res://vendor/vwm/construction/scripts/domain/role_profiles.gd")

@export var id: int = -1
@export var display_name: String = "Player"
@export var position_role: String = "Outside Hitter"
@export var position_code: String = "OH"
@export_range(15, 45) var age: int = 24
@export_range(0, 25) var professional_experience: int = 3
@export_range(1, 100) var potential: int = 70
## Per-attribute ceiling this player was generated with, keyed by attribute
## name -- the same ceilings `potential` was scored from, kept individually
## rather than only as their aggregate. `VolleyballPlayerGenerator` populates this;
## hand-authored fixture players (`GameManager._make_player()`) leave it empty,
## which callers read as "no ceiling data, fall back to the current value."
## This is what lets a potential-attribute wheel be exact today; when scouting
## is implemented, obfuscating a prospect's potential means showing a range or
## an estimate derived from this data rather than this data itself, not
## changing what is stored here.
@export var attribute_ceilings: Dictionary = {}
## Fractional progress toward the next point of each attribute.
##
## Training used to move an attribute by a whole point or not at all, so the
## smallest change the model could express was also the largest and there was no
## such thing as a slow week. This carries the remainder between weeks.
@export var training_progress: Dictionary = {}
## Long-term relationship with the player's current club. Unlike the old
## `morale` field this does not directly modify rally execution; playing time,
## results and management decisions move it over weeks and matches.
@export_range(0.0, 1.0) var satisfaction: float = 0.70
## External standing, not ability. Reputation affects how the world values and
## talks about a player; it is deliberately absent from ability scoring.
@export_range(1, 100) var reputation: int = 20
@export_enum("Available", "Resting", "Injured", "Suspended") var availability: String = "Available"

## How many weeks this club has had this voli under its own eyes.
##
## The observation half of `ScoutingSystem.confidence()` -- a scout tells you
## about somebody you have never met, and time tells you the rest. Saturates
## after about a season and a half, so this climbing forever costs nothing.
##
## Stored on the voli rather than in a per-career table keyed by id, because a
## voli who moves clubs takes their history with them and a side table would have
## to be told about every transfer to stay correct.
@export var weeks_observed: int = 0

@export_category("Physical")
@export_range(150.0, 220.0, 0.5) var height_cm: float = 188.0
@export_range(50.0, 130.0, 0.5) var mass_kg: float = 82.0
@export_range(150.0, 235.0, 0.5) var wingspan_cm: float = 191.0
@export_range(1, 100) var acceleration: int = 50
@export_range(1, 100) var lateral_speed: int = 50
@export_range(1, 100) var transition_speed: int = 50
## Leap capacity: how high this player drives off the floor. It is NOT a reach
## height despite the name, which is retained only because saves carry it.
## Reach is derived -- see `jumping_reach_cm()` -- because how high a player
## can touch is a product of three separate things: how tall they stand, how
## long their arms are, and how well they jump. A short player with a huge leap
## and a tall player who barely leaves the floor can touch the same ball.
@export_range(1, 100) var jump_reach: int = 50
@export_range(1, 100) var explosiveness: int = 50
@export_range(1, 100) var stamina: int = 50
## Willingness to repeatedly pursue, cover and transition. Stamina is the
## physical capacity; work rate is how aggressively the player spends it.
@export_range(1, 100) var work_rate: int = 50
@export_range(1, 100) var arm_speed: int = 50
## Length of one full approach stride. Correlates with height but is scouted
## independently: two players of equal height can carry very different footwork.
@export_range(0.55, 1.15, 0.01) var stride_length_m: float = 0.83

@export_category("Technical")
@export_range(1, 100) var serve_power: int = 50
@export_range(1, 100) var serve_accuracy: int = 50
@export_range(1, 100) var serve_technique: int = 50
@export_range(1, 100) var serve_placement: int = 50
@export_range(1, 100) var serve_consistency: int = 50
@export_range(1, 100) var serve_aggression: int = 50
@export_range(1, 100) var serve_variation: int = 50
@export_range(1, 100) var reception: int = 50
@export_range(1, 100) var reception_balance: int = 50
@export_range(1, 100) var reception_stability: int = 50
@export_range(1, 100) var set_accuracy: int = 50
@export_range(1, 100) var set_balance: int = 50
@export_range(1, 100) var set_stability: int = 50
@export_range(1, 100) var tempo_control: int = 50
@export_range(1, 100) var set_disguise: int = 50
@export_range(1, 100) var hand_control: int = 50
@export_range(1, 100) var attack_power: int = 50
@export_range(1, 100) var attack_accuracy: int = 50
@export_range(1, 100) var approach_timing: int = 50
@export_range(1, 100) var tooling: int = 50
@export_range(1, 100) var feinting: int = 50
@export_range(1, 100) var finesse: int = 50
@export_range(1, 100) var shot_variety: int = 50
@export_range(1, 100) var block_timing: int = 50
@export_range(1, 100) var ball_control: int = 50
@export_range(1, 100) var dig_control: int = 50

@export_category("Mental and Tactical")
@export_range(1, 100) var court_vision: int = 50
@export_range(1, 100) var anticipation: int = 50
@export_range(1, 100) var decision_making: int = 50
@export_range(1, 100) var composure: int = 50
@export_range(1, 100) var tactical_discipline: int = 50
@export_range(1, 100) var improvisation: int = 50
## How much the rest of the side plays up around this player.
##
## Out of `ABILITY_ATTRIBUTES` for the same reason as `ego` and `body_type`:
## every ability attribute belongs to a category that
## `AttributeProfiles.category_score()` averages into a rating, and leadership
## does not make *this* player better at volleyball -- it acts on everybody
## else. Scoring a captain higher for it inflated Mental & Tactical, and Overall
## with it, for a quality the player never applies to their own contacts.
##
## Read by `GameManager` for how a squad's confidence moves after a point and
## how far a collapse is allowed to run, and by
## `SignatureMoveModel.crush_capability()` -- a hitter the room follows goes for
## the big one more readily.
@export_range(1, 100) var leadership: int = 50
## How hard this setter's distribution pattern is to scout across a whole
## match -- varying tempo and target selection rather than falling into
## readable habits. A single-contact skill would live in the "Technical"
## category above (see `set_disguise`, which masks one release's mechanics);
## this is a pattern read over many decisions, so it belongs here instead.
@export_range(1, 100) var unpredictability: int = 50

@export_category("State")
@export_range(0.0, 1.0) var fatigue: float = 0.0
@export_range(-1.0, 1.0) var current_form: float = 0.0
## Point-to-point belief during the current match. This name intentionally
## differs from perception `confidence`, which means certainty in a ball read.
@export_range(-1.0, 1.0) var match_confidence: float = 0.0
@export var traits: Array[String] = []
@export_enum("Standing", "Jump Topspin", "Jump Float", "Hybrid", "Sky Ball") var primary_serve_style: String = "Standing"
@export var serve_style_proficiencies: Dictionary = {}
@export_enum("Right", "Left") var dominant_hand: String = "Right"

## Morphology. Always been true of everyone, remarked on by nobody -- handled
## the way academy managers being "arguably alien" is handled in
## `docs/world/STYLE_AND_SETTING.md`: never pinned down, never explained.
##
## Categorical like `dominant_hand`, deliberately **not** an entry in
## `ABILITY_ATTRIBUTES`. It is a fact about a player, not a skill they have,
## and the two-way regression check that sums `ABILITY_ATTRIBUTES` against
## `AttributeProfiles.CATEGORY_ATTRIBUTES` would demand a category for it.
##
## Distribution is uniform in every region without exception -- see
## `PlayerGenerator.BODY_TYPES`. That is a fixed property of the world, not a
## tuning value.
@export_enum("Vegi", "Avi", "Cani", "Feli", "Ursi", "Simi")
var body_type: String = "Vegi"
@export_range(1, 100) var adaptability: int = 50

## How much a player backs themselves -- whether they take the shot on or take
## the safe one.
##
## Deliberately **not** in `ABILITY_ATTRIBUTES`, for the same reason `body_type`
## is not. It is a temperament rather than a skill, and every ability attribute
## belongs to a category that `AttributeProfiles.category_score()` averages into
## a rating. Ego does not make a player better, so folding it into a capability
## score would inflate Mental & Tactical -- and therefore Overall -- for a trait
## whose high end is not an improvement. A hitter with ego 90 is not stronger
## than one with 50; they attempt different shots and fail differently.
##
## **Ego is how hard a decision is to change, not how big a swing is.** It used
## to be both, and doing two jobs it was only ever read as one: every call site
## asked it how hard this player hits. That is `aggression` below. What is left
## here is the question nothing else in the engine could ask -- once this voli
## has decided, how easily do they decide otherwise?
##
## High ego holds the read: a blocker who chose line closes line even as the
## hitter turns cross, a setter who called the ball does not give it up, a voli
## crossing somebody else's ground expects the other one to move. Low ego
## changes course readily, yields a contested ball, and gives way in a corridor.
## Neither is better. High ego is right when the read was right.
##
## It cuts both ways and the cost is late: changing a decision late is worse
## than changing it early *and* worse than never changing it, which is why this
## is a separate axis from being correct.
@export_range(1, 100) var ego: int = 50
## How committed this voli is to creating a terminal play.
##
## Out of `ABILITY_ATTRIBUTES` with `ego` and `leadership`, for the same reason:
## a temperament is not a capability, and folding it into a category rating
## would inflate Overall for a trait whose high end is not an improvement.
##
## This is the axis `ego` was silently carrying. High aggression swings bigger
## than the situation asks and sails long, closes a block lane hard enough to
## risk arriving into a teammate, and takes the second ball to attack rather
## than to keep the rally alive. Low aggression leaves something on the ball and
## gets dug, blocks to touch rather than to stuff, and plays the percentage.
##
## Separate from ego on purpose: a voli can be certain and cautious (holds a
## conservative read), or uncertain and violent (changes their mind, then
## crushes it). Those are different players and the engine could not tell them
## apart while one number meant both.
@export_range(1, 100) var aggression: int = 50
## Where this player was raised, and where they actually play now. These are
## deliberately separate: talent is *born* roughly evenly across the world but
## *accumulates* wherever the money is, and collapsing the two would erase the
## most interesting thing about a player's biography. A'ace's squads are full
## of stars it did not produce; Ĭspayk raises players it cannot keep.
##
## Blank for hand-authored fixture players that predate the world population;
## every generated player carries both.
@export var home_region: String = ""
@export var club_region: String = ""
@export var primary_position: String = "Outside Hitter"
@export var natural_positions: Array[String] = []
@export var position_familiarity: Dictionary = {}
## The regions whose food this voli is comfortable with.
##
## Starts as where they grew up and grows: a season at a club in a region, or
## long enough rooming with somebody from one. Stored as region names rather
## than as a number because it is meant to be **read on a card** -- "eats:
## Landavol, Xérvu" is something a player can see, understand and predict, and a
## float called `adaptability_to_foreign_cuisine` would be the same data with
## nobody able to say what it meant. See `FoodSupply`.
@export var palate_regions: Array[String] = []
@export var situation_experience: Dictionary = {}
@export var position_training_target: String = ""

static var ABILITY_ATTRIBUTES = AttributeRegistry.ABILITY_ATTRIBUTES

static var POSITION_WEIGHTS = RoleProfiles.POSITION_WEIGHTS

## Tactical step-count scaling for the attack run-up. This is a system demand,
## not a physical limit: a middle with elite acceleration still runs a compact
## approach because quick-tempo offence needs them at the net early. Outsides and
## opposites get the full four-step runway.
static var POSITION_APPROACH_STEP_MODIFIER = RoleProfiles.POSITION_APPROACH_STEP_MODIFIER

## Quick-tempo footwork punishes sloppiness harder than a slow high-ball
## approach, so compact-approach roles also carry a tighter tolerance band.
static var POSITION_APPROACH_TOLERANCE_MODIFIER = RoleProfiles.POSITION_APPROACH_TOLERANCE_MODIFIER

const SYSTEM_FIT_APPROACH_DISTANCE := &"attack_approach_distance"
const SYSTEM_FIT_SET_RELEASE := &"set_release_interval"
const SYSTEM_FIT_BLOCK_ENGAGEMENT := &"block_engagement_distance"
const SYSTEM_FIT_DEFENSIVE_DEPTH := &"defensive_depth"

## Cache of derived system-fit bands. Rebuilt whenever career attributes change;
## never serialised, because it is fully recoverable from the attributes.
var _system_fit_profiles: Dictionary = {}


func current_ability_score() -> int:
	var role_attributes: Array = POSITION_WEIGHTS.get(position_role, ABILITY_ATTRIBUTES)
	var role_total := 0.0
	for attribute_name in role_attributes:
		role_total += float(get(str(attribute_name)))
	var role_score := role_total / maxf(float(role_attributes.size()), 1.0)
	var complete_total := 0.0
	for attribute_name in ABILITY_ATTRIBUTES:
		complete_total += float(get(attribute_name))
	var complete_score := complete_total / float(ABILITY_ATTRIBUTES.size())
	return clampi(roundi(role_score * 0.75 + complete_score * 0.25), 1, 100)


## Standing reach normalized to a 1-100 rating, shared by `usable_attack_power`,
## `baseline_defensive_range`, and the Physical wheel's own "Reach" axis. Never
## overridden by ceilings: reach is physical geometry, not a skill with a
## ceiling to develop toward, so a potential reading equals the current one.
func reach_rating() -> int:
	return clampi(roundi(inverse_lerp(190.0, 280.0, standing_reach_cm()) * 100.0), 1, 100)


## `overrides` lets a caller substitute individual attributes -- ceilings, for
## a potential-power reading -- without a second copy of these weights. Body
## measurements are never overridden: mass is physical geometry, not a skill
## with a ceiling to develop toward.
func usable_attack_power(overrides: Dictionary = {}) -> int:
	var normalized_mass := clampf(inverse_lerp(55.0, 115.0, mass_kg) * 100.0, 1.0, 100.0)
	return clampi(roundi(
		float(overrides.get("attack_power", attack_power)) * 0.25 + normalized_mass * 0.10 \
		+ float(overrides.get("explosiveness", explosiveness)) * 0.18 \
		+ float(overrides.get("transition_speed", transition_speed)) * 0.12 \
		+ float(overrides.get("arm_speed", arm_speed)) * 0.20 \
		+ float(overrides.get("approach_timing", approach_timing)) * 0.15), 1, 100)


## Deliberately excludes both `anticipation` and `ball_control`: reading the
## play is a mental skill with its own axis on Mental & Tactical, and turning
## a touch into a playable ball is a hands skill with its own axis on
## Defensive -- folding either in here would hide a player who covers court
## well but reads or converts poorly (or vice versa) behind one blended
## number. What remains -- acceleration, lateral speed, reach, stamina --
## converges on a single physical question, how much court this player can
## physically get to, the same way `usable_attack_power` converges several
## physical inputs into one hitting-power reading, so it stays merged.
func baseline_defensive_range(overrides: Dictionary = {}) -> int:
	return clampi(roundi(
		float(overrides.get("acceleration", acceleration)) * 0.28 \
		+ float(overrides.get("lateral_speed", lateral_speed)) * 0.32 \
		+ float(reach_rating()) * 0.18 \
		+ float(overrides.get("stamina", stamina)) * 0.12 \
		+ float(overrides.get("work_rate", work_rate)) * 0.10), 1, 100)


## Effort changes how often a player reaches their movement ceiling, not the
## ceiling itself. The narrow band keeps work rate meaningful without turning
## willingness into raw speed.
func effort_scale() -> float:
	return lerpf(0.96, 1.04, float(work_rate) / 100.0)


## Confidence is intentionally a small execution modifier. Composed players
## remain closer to their baseline in either direction; emotional players gain
## more from a surge and lose more after a collapse.
func confidence_execution_scale() -> float:
	var sensitivity := lerpf(0.06, 0.02, float(composure) / 100.0)
	return 1.0 + match_confidence * sensitivity


## Default stride for a player of this height. Roughly 0.43x standing height,
## which is the middle of the observed range for an attacking approach.
func default_stride_length_m() -> float:
	return clampf(height_cm / 100.0 * 0.43, 0.55, 1.15)


## How many strides this player needs before their run-up reaches usable speed.
## Explosive players get there in three; slower builders need four and a half.
func effective_approach_step_count() -> float:
	var physical_steps := lerpf(4.5, 3.0, float(acceleration) / 100.0)
	return physical_steps * float(
		POSITION_APPROACH_STEP_MODIFIER.get(position_role, 1.0)
	)


## Rebuilds every derived system-fit band from current career attributes. Call
## after generation, after training changes, and after deserialisation.
func refresh_system_fit_profiles() -> void:
	_system_fit_profiles = {}

	## Attack approach: stride length x the strides this player actually needs.
	var adaptability_fraction := float(adaptability) / 100.0
	var approach_tolerance := lerpf(0.35, 1.10, adaptability_fraction) * float(
		POSITION_APPROACH_TOLERANCE_MODIFIER.get(position_role, 1.0)
	)
	_system_fit_profiles[SYSTEM_FIT_APPROACH_DISTANCE] = SystemFitProfile.create(
		SYSTEM_FIT_APPROACH_DISTANCE,
		stride_length_m * effective_approach_step_count(),
		approach_tolerance,
		"Ideal approach distance",
	)

	## Setter release rhythm: how fast this setter naturally gets the ball out.
	_system_fit_profiles[SYSTEM_FIT_SET_RELEASE] = SystemFitProfile.create(
		SYSTEM_FIT_SET_RELEASE,
		lerpf(0.55, 0.30, clampf(
			(float(tempo_control) * 0.6 + float(hand_control) * 0.4) / 100.0, 0.0, 1.0
		)),
		lerpf(0.05, 0.16, adaptability_fraction),
		"Preferred set release interval",
	)

	## Block engagement: how late this blocker can keep reading before they must
	## commit to the closing burst. Better readers hold longer and telegraph less.
	_system_fit_profiles[SYSTEM_FIT_BLOCK_ENGAGEMENT] = SystemFitProfile.create(
		SYSTEM_FIT_BLOCK_ENGAGEMENT,
		lerpf(1.8, 0.9, clampf((
			float(anticipation) * 0.45 + float(block_timing) * 0.35
			+ float(lateral_speed) * 0.20
		) / 100.0, 0.0, 1.0)),
		lerpf(0.30, 0.85, adaptability_fraction),
		"Preferred block engagement distance",
	)

	## Defensive depth: gamblers read shallow, coverage defenders sit deep.
	_system_fit_profiles[SYSTEM_FIT_DEFENSIVE_DEPTH] = SystemFitProfile.create(
		SYSTEM_FIT_DEFENSIVE_DEPTH,
		lerpf(2.2, 4.6, 1.0 - clampf((
			float(anticipation) * 0.5 + float(reception) * 0.3
			+ float(lateral_speed) * 0.2
		) / 100.0, 0.0, 1.0)),
		lerpf(0.45, 1.20, adaptability_fraction),
		"Preferred defensive depth",
	)


## Lazily-initialised accessor. Returns null only for an unknown key.
func system_fit(profile_key: StringName) -> SystemFitProfile:
	if _system_fit_profiles.is_empty():
		refresh_system_fit_profiles()
	return _system_fit_profiles.get(profile_key, null) as SystemFitProfile


func ideal_approach_distance_meters() -> float:
	var profile := system_fit(SYSTEM_FIT_APPROACH_DISTANCE)
	return profile.ideal_value if profile != null else 2.4


func approach_tolerance_meters() -> float:
	var profile := system_fit(SYSTEM_FIT_APPROACH_DISTANCE)
	return profile.tolerance if profile != null else 0.7


## Transient tolerance scaling. A tired player has less room to improvise their
## way back onto their mark, so the in-system band tightens under fatigue.
func system_fit_tolerance_scale() -> float:
	return lerpf(1.0, 0.78, clampf(fatigue, 0.0, 1.0))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"position_role": position_role,
		"position_code": position_code,
		"age": age,
		"professional_experience": professional_experience,
		"potential": potential,
		"satisfaction": satisfaction,
		## Keep the legacy key while older builds may still load these saves.
		"morale": satisfaction,
		"reputation": reputation,
		"availability": availability,
		"height_cm": height_cm,
		"mass_kg": mass_kg,
		"wingspan_cm": wingspan_cm,
		"acceleration": acceleration,
		"lateral_speed": lateral_speed,
		"transition_speed": transition_speed,
		"jump_reach": jump_reach,
		"explosiveness": explosiveness,
		"stamina": stamina,
		"work_rate": work_rate,
		"arm_speed": arm_speed,
		"stride_length_m": stride_length_m,
		"serve_power": serve_power,
		"serve_accuracy": serve_accuracy,
		"serve_technique": serve_technique,
		"serve_placement": serve_placement,
		"serve_consistency": serve_consistency,
		"serve_aggression": serve_aggression,
		"serve_variation": serve_variation,
		"reception": reception,
		"reception_balance": reception_balance,
		"reception_stability": reception_stability,
		"set_accuracy": set_accuracy,
		"set_balance": set_balance,
		"set_stability": set_stability,
		"tempo_control": tempo_control,
		"set_disguise": set_disguise,
		"hand_control": hand_control,
		"unpredictability": unpredictability,
		"attack_power": attack_power,
		"attack_accuracy": attack_accuracy,
		"approach_timing": approach_timing,
		"tooling": tooling,
		"feinting": feinting,
		"finesse": finesse,
		"shot_variety": shot_variety,
		"block_timing": block_timing,
		"ball_control": ball_control,
		"dig_control": dig_control,
		"court_vision": court_vision,
		"anticipation": anticipation,
		"decision_making": decision_making,
		"composure": composure,
		"tactical_discipline": tactical_discipline,
		"improvisation": improvisation,
		"leadership": leadership,
		"fatigue": fatigue,
		"current_form": current_form,
		"match_confidence": match_confidence,
		"traits": traits.duplicate(),
		"primary_serve_style": primary_serve_style,
		"serve_style_proficiencies": serve_style_proficiencies.duplicate(true),
		"dominant_hand": dominant_hand, "body_type": body_type,
		"adaptability": adaptability, "ego": ego, "aggression": aggression,
		"home_region": home_region, "club_region": club_region,
		"primary_position": primary_position, "natural_positions": natural_positions.duplicate(),
		"position_familiarity": position_familiarity.duplicate(true),
		"palate_regions": Array(palate_regions).duplicate(),
		"situation_experience": situation_experience.duplicate(true),
		"position_training_target": position_training_target,
		"weeks_observed": weeks_observed,
		"attribute_ceilings": attribute_ceilings.duplicate(true),
		"training_progress": training_progress.duplicate(true),
	}


static func from_dict(data: Dictionary) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = int(data.get("id", -1))
	player.display_name = str(data.get("display_name", "Player"))
	player.position_role = str(data.get("position_role", "Outside Hitter"))
	player.position_code = str(data.get("position_code", "OH"))
	player.age = clampi(int(data.get("age", 24)), 15, 45)
	player.professional_experience = clampi(int(data.get("professional_experience", 3)), 0, 25)
	player.potential = clampi(int(data.get("potential", 70)), 1, 100)
	player.satisfaction = clampf(float(
		data.get("satisfaction", data.get("morale", 0.70))
	), 0.0, 1.0)
	player.reputation = clampi(int(data.get("reputation", 20)), 1, 100)
	player.availability = str(data.get("availability", "Available"))
	player.apply_role_physical_defaults()
	player.height_cm = clampf(float(data.get("height_cm", player.height_cm)), 150.0, 220.0)
	player.mass_kg = clampf(float(data.get("mass_kg", player.mass_kg)), 50.0, 130.0)
	player.wingspan_cm = clampf(float(data.get("wingspan_cm", player.wingspan_cm)), 150.0, 235.0)
	for property_name in [
		"acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness",
		"stamina", "work_rate", "arm_speed", "serve_power", "serve_accuracy", "reception",
		"reception_balance", "reception_stability",
		"set_accuracy", "set_balance", "set_stability", "tempo_control", "set_disguise", "hand_control",
		"unpredictability",
		"attack_power", "attack_accuracy", "approach_timing", "tooling", "feinting", "finesse", "shot_variety",
		"block_timing", "ball_control", "dig_control", "court_vision", "anticipation",
		"decision_making", "composure", "tactical_discipline", "improvisation", "leadership",
	]:
		player.set(property_name, clampi(int(data.get(property_name, 50)), 1, 100))
	var legacy_serve_accuracy := int(data.get("serve_accuracy", 50))
	for property_name in ["serve_technique", "serve_placement", "serve_consistency",
		"serve_aggression", "serve_variation"]:
		player.set(property_name, clampi(int(data.get(property_name, legacy_serve_accuracy)), 1, 100))
	player.primary_serve_style = str(data.get("primary_serve_style", "Standing"))
	player.serve_style_proficiencies = Dictionary(
		data.get("serve_style_proficiencies", {})
	).duplicate(true)
	player.dominant_hand = str(data.get("dominant_hand", "Right"))
	## Saves written before body types load as Homi, the no-modifier baseline,
	## so an old career is unchanged rather than silently re-rolled.
	## Saves written before Vegi replaced Homi still carry the old string.
	## Dropping it would leave those volis with a body type nothing can draw.
	player.body_type = str(data.get("body_type", "Vegi"))
	if player.body_type == "Homi":
		player.body_type = "Vegi"
	player.ego = clampi(int(data.get("ego", 50)), 1, 100)
	## Saves written before ego and aggression were separated carry one number
	## that meant both, and every simulation reader of it meant aggression. An
	## old career keeps the swing it had rather than reverting to the default.
	player.aggression = clampi(int(data.get("aggression", player.ego)), 1, 100)
	player.home_region = str(data.get("home_region", ""))
	player.club_region = str(data.get("club_region", player.home_region))
	player.adaptability = clampi(int(data.get("adaptability", 50)), 1, 100)
	player.primary_position = str(data.get("primary_position", player.position_role))
	player.natural_positions = Array(data.get("natural_positions", [player.primary_position]), TYPE_STRING, "", null)
	player.position_familiarity = Dictionary(data.get("position_familiarity", {player.primary_position: 90})).duplicate(true)
	player.palate_regions.clear()
	for region in Array(data.get("palate_regions", [player.home_region])):
		player.palate_regions.append(str(region))
	player.situation_experience = Dictionary(data.get("situation_experience", {})).duplicate(true)
	player.position_training_target = str(data.get("position_training_target", ""))
	player.fatigue = clampf(float(data.get("fatigue", 0.0)), 0.0, 1.0)
	player.current_form = clampf(float(data.get("current_form", 0.0)), -1.0, 1.0)
	player.match_confidence = clampf(float(data.get("match_confidence", 0.0)), -1.0, 1.0)
	player.traits = Array(data.get("traits", []), TYPE_STRING, "", null)
	## Legacy saves have no stride length; derive it from height so existing
	## players keep a sane approach instead of collapsing to the export default.
	player.stride_length_m = clampf(float(
		data.get("stride_length_m", player.default_stride_length_m())
	), 0.55, 1.15)
	player.weeks_observed = int(data.get("weeks_observed", 0))
	player.attribute_ceilings = Dictionary(data.get("attribute_ceilings", {})).duplicate(true)
	player.training_progress = Dictionary(data.get("training_progress", {})).duplicate(true)
	player.refresh_system_fit_profiles()
	return player


func active_serve_style_score() -> int:
	return clampi(int(serve_style_proficiencies.get(primary_serve_style, 50)), 1, 100)


func standing_reach_cm() -> float:
	return height_cm * 1.215 + (wingspan_cm - height_cm) * 0.32


## Where this voli's shoulder sits, in metres off the floor.
##
## **The repository already commits to this**, once, in
## `BodyTypeModels.UNIVERSAL_RATIOS` -- the shared figure every body type is a
## pull away from, authored with its basis recorded: *"Feli's shoulders sat at
## 0.745 of its height and Avi's at 0.750, against roughly 0.82 on a human."*
## Reading it here rather than authoring a second one is what makes the
## simulation and the drawn body the same body, which is M3's own exit condition.
func shoulder_height_meters() -> float:
	return height_cm / 100.0 * float(
		BodyTypeModels.UNIVERSAL_RATIOS.get("shoulder_y", 0.815)
	)


## Arm length, in metres, from the shoulder to the fingertips.
##
## Derived rather than authored, and individual rather than shared: a raised arm
## puts the fingertips at `standing_reach`, so the arm is what remains above the
## shoulder. `standing_reach_cm()` already carries this voli's own wingspan, so a
## long-armed voli gets a long arm without a second opinion about their build.
##
## The shared figure is the check rather than the source. `UNIVERSAL_RATIOS` puts
## the fingertips at 0.395 of height and the shoulder at 0.815, so its arm is
## 0.420 of height -- and for an average build this derivation lands within a
## centimetre of that. Two independent routes to one number agreeing is what says
## the shoulder ratio is being read correctly.
func arm_length_meters() -> float:
	return maxf(standing_reach_cm() / 100.0 - shoulder_height_meters(), 0.0)


## **How far in front of the body a contact at this height is taken**, in metres.
##
## M3's missing relation, and every term in it already existed. The arm is a
## segment of known length anchored at a known shoulder; a ball met at a known
## height fixes the angle; the horizontal offset is Pythagoras. Nothing is
## authored here -- not a ratio, not a distance.
##
## Zero above the shoulder, because an overhead contact is taken above the body
## rather than in front of it, and zero again once the ball is further below the
## shoulder than the arm is long -- a ball at the ankles is not reached in front
## of a standing body at all, it is reached by leaving the feet, which is a
## posture question the contact envelope owns. Neither boundary was placed; both
## are what the geometry does. See `docs/review/BODY_CENTRE_SCOPE.md`.
func contact_offset_meters(contact_height_meters: float) -> float:
	var arm := arm_length_meters()
	if arm <= 0.0:
		return 0.0
	var drop := shoulder_height_meters() - contact_height_meters
	if drop <= 0.0 or drop >= arm:
		return 0.0
	return sqrt(arm * arm - drop * drop)



## How high this player can actually touch a ball, in centimetres: standing
## reach (height plus arm length) plus what their leap adds.
##
## `effort` scales the leap between a standing hop (0.0) and a full committed
## jump off an approach (1.0), because the same player reaches very different
## heights setting off their back foot and swinging off a four-step run-up.
## This is the single place the three inputs are combined; callers that need a
## reach must ask here rather than re-adding height and leap themselves.
## Vertical leap band, in centimetres, from no jumping ability to elite. Named
## because the attack-versus-block contest is proportional to this number -- see
## `jumping_reach_cm()` -- so anyone retuning it is retuning blocking.
const JUMP_LEAP_MIN_CM: float = 20.0
const JUMP_LEAP_MAX_CM: float = 110.0


func jumping_reach_cm(effort: float = 1.0) -> float:
	## Leap carries the attack-versus-block contest, which is why this band is
	## wide and generous rather than sober.
	##
	## That contest is decided by one number: how far a hitter's contact sits
	## above a blocker's reach. Because a blocker jumps at a fraction of a
	## hitter's effort, that difference works out at roughly
	## `leap * (1 - blocker_effort)` -- it is *proportional to the leap itself*.
	## At the old 12-78 cm band an average hitter contacted 9 cm above the
	## blocker and a poor one 0 cm, so almost every swing met hands and the
	## contest had no room to resolve. Widening the leap widens the attacking
	## advantage without touching `standing_reach_cm()`, and it moves the contest
	## off body height -- which a player is born with -- and onto jump and
	## explosiveness, which they can train.
	##
	## It also puts contact where the sport puts it. A hitter now meets the ball
	## 22 cm above the tape at the bottom of the range and 87 cm at the top,
	## against 10-57 cm before; real contact is 60-90 cm above a 2.43 m net.
	##
	## And it suits the setting: small players making enormous leaps is exactly
	## the register this world plays in.
	var leap := lerpf(JUMP_LEAP_MIN_CM, JUMP_LEAP_MAX_CM, float(jump_reach) / 100.0) \
		* lerpf(0.72, 1.0, float(explosiveness) / 100.0) \
		* (1.0 - fatigue * 0.35)
	return standing_reach_cm() + leap * clampf(effort, 0.0, 1.0)


func apply_role_physical_defaults() -> void:
	var defaults: Array = {
		"Setter": [188.0, 82.0, 191.0, 70, 64, 68],
		"Outside Hitter": [193.0, 88.0, 198.0, 78, 75, 78],
		"Middle Blocker": [203.0, 95.0, 211.0, 86, 48, 62],
		"Opposite": [198.0, 94.0, 205.0, 83, 54, 66],
		"Libero": [178.0, 72.0, 181.0, 72, 88, 91],
	}.get(position_role, [188.0, 82.0, 191.0, 68, 62, 68])
	height_cm = float(defaults[0])
	mass_kg = float(defaults[1])
	wingspan_cm = float(defaults[2])
	explosiveness = int(defaults[3])
	reception_balance = int(defaults[4])
	reception_stability = int(defaults[5])
	stride_length_m = default_stride_length_m()
	_system_fit_profiles = {}
