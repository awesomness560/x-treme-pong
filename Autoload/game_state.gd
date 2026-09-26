extends Node

signal camera_shook(trauma_amount : float)

signal boss_new_health(health : float)
signal take_damage(amount : float)
signal boss_dead

signal next_round
signal start_round
## Fired mid-transition, while the dotted line is off-screen and nothing is
## visible — the moment to actually spawn the next boss/border.
signal spawn_encounter

signal ult_gained(amount: float, kind: GainKind)
signal ult_armed_changed(armed: bool)
signal ult_spent()

signal ult_started(character: Character)
signal ult_charge_progress(t: float)
signal ult_launched()
signal ult_impact()
signal ult_ended()

## True for the whole ult, from cut-in to the end.
var ult_active := false
## Paddles ignore input while this is set.
var input_locked := false

enum GainKind { SMASH, BORDER, IGNITION, DAMAGE_TAKEN, REFUND }
enum Character { PINK, BLUE, GREEN }

enum UPGRADE_RARITY { COMMON, RARE, LEGENDARY }
enum UPGRADE_CATAGORY { HEAT, STRIKE, ENDURANCE, ULTIMATE, HEAL}

## Lightning may join later; the AI/border color-switch and round manager's
## gimmick spawn both key off this, so adding one there is all a 4th needs.
enum BossType { FIRE, EARTH, WATER }

## The AI and border scripts react to this themselves to recolor.
signal boss_type_changed(type: BossType)
var boss_type := BossType.FIRE :
	set(value):
		boss_type = value
		boss_type_changed.emit(value)

## No-repeat shuffle bag: every boss type is drawn once, in a random order,
## before any of them can come up again.
var _boss_bag : Array[BossType] = []

func roll_next_boss_type() -> BossType:
	if _boss_bag.is_empty():
		_boss_bag.assign(BossType.values())
		_boss_bag.shuffle()
	return _boss_bag.pop_back()

var character := Character.PINK

signal player_health_changed
## Fires only on an actual hit (not on healing) — take_damage above is the
## boss/border's damage signal, this one is the player's.
signal player_damaged
## Emitted wherever a hit takes player_health to 0 or below — game_over.gd
## listens for this to show the game-over screen.
signal game_over

## Run-scoped counters for the game-over screen's stat display.
var stat_damage_dealt := 0.0
var stat_smashes := 0
var stat_ignitions := 0

## True until Last Stand consumes it to survive one lethal hit this run.
var _last_stand_available := false

func grant_last_stand() -> void:
	_last_stand_available = true

## Call wherever a hit is about to take player_health to 0 or below. Returns
## true (and consumes the save) if that hit should be survived instead.
func consume_last_stand() -> bool:
	if not _last_stand_available:
		return false
	_last_stand_available = false
	return true

var ball: Ball
var player: Paddle
var enemy: EnemyPaddle
var ult_runner: UltRunner
var ult_charge_manager: UltCharge
var cut_in : UltCutIn
var ui : UI
var border : Border
var paddle_flex : PaddleFlex

var combo_multiplier : float = 1.0
var ball_ignited : bool = false

var boss_health : float = 1.0 :
	set (value) :
		boss_health = value
		boss_new_health.emit(value)

var last_hit_perfect : bool = false
var last_hit_was_smash := false
var ball_ignitable : bool = false

## 0 to 1. Normalized, so the UI never needs to know a character's max.
var ult_charge := 0.0
var ult_armed := false
## Charge per second right now, smoothed. Drives the edge spark.
var ult_rate := 0.0

## The run's current health cap. Second Wind's own heal cap and the "should
## we offer it" check in upgrades_ui.gd both read this instead of a
## hardcoded 3, so an upgrade like Glass Cannon can actually lower it.
var max_player_health := 3

var player_health = max_player_health :
	set (value):
		player_health = value
		player_health_changed.emit()

## Immortal sets this so Second Wind stops being offered for the rest of
## the run — checked in upgrades_ui.gd's "should we offer it" gate.
var healing_blocked := false

## Sum of every "+X% damage" bonus currently active, from any source
## (Glass Cannon, Fever, event-triggered upgrades like Combustion's proc
## going through deal_damage() below) — final damage is amount * (1 +
## damage_bonus). Additive on purpose: two +75% upgrades together should
## read as +150%, not compound into +206%. An upgrade only multiplies
## instead of adding here if its own text explicitly says so.
var damage_bonus := 0.0

## Applies the bonus, emits take_damage, and hands back the final amount
## actually dealt — callers that also need to show it (damage numbers) use
## the return value instead of re-deriving it themselves.
func deal_damage(amount: float) -> float:
	var final_amount := amount * (1.0 + damage_bonus)
	stat_damage_dealt += final_amount
	take_damage.emit(final_amount)
	return final_amount

## Additive bonus applied to every new boss's base `skill`, and the
## cumulative multiplier applied to every new border's base
## `starting_health` — both grow every round via _scale_round() below.
var boss_skill_bonus := 0.0
var boss_health_multiplier := 1.0

func _scale_round() -> void:
	boss_skill_bonus += 0.2
	# Additive, not compounding — round 5 is x2.2, not x2.86.
	boss_health_multiplier += 0.3

## Restores every run-scoped field back to its starting value. Called by the
## restart button before reloading the scene — autoloads (unlike scene
## nodes) survive a scene reload on their own, so this has to be explicit.
func reset_run() -> void:
	max_player_health = 3
	player_health = max_player_health
	damage_bonus = 0.0
	boss_skill_bonus = 0.0
	boss_health_multiplier = 1.0
	combo_multiplier = 1.0
	last_hit_perfect = false
	last_hit_was_smash = false
	ball_ignited = false
	ball_ignitable = false
	ult_charge = 0.0
	ult_armed = false
	ult_rate = 0.0
	input_locked = false
	ult_active = false
	_last_stand_available = false
	healing_blocked = false
	_boss_bag.clear()
	stat_damage_dealt = 0.0
	stat_smashes = 0
	stat_ignitions = 0
