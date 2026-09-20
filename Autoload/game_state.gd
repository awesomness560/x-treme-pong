extends Node

signal boss_new_health(health : float)
signal take_damage(amount : float)
signal boss_dead

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

var character := Character.PINK

signal player_health_changed

var ball: Ball
var player: Paddle
var enemy: EnemyPaddle
var ult_runner: UltRunner
var ult_charge_manager: UltCharge
var cut_in : UltCutIn

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
