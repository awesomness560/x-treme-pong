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

var ball: Ball
var player: Paddle
var enemy: EnemyPaddle
var ult_runner: UltRunner
var ult_charge_manager: UltCharge
var cut_in : UltCutIn
var ui : UI
var border : Border

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

var player_health = 3 :
	set (value):
		player_health = value
		player_health_changed.emit()

func _scale_round() -> void:
	pass
