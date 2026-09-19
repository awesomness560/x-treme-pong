extends Node

signal boss_new_health(health : float)
signal take_damage(amount : float)
signal boss_dead

var ball: Ball
var player: Paddle
var enemy: EnemyPaddle

var combo_multiplier : float = 1.0
var ball_ignited : bool = false

var boss_health : float = 1.0 :
	set (value) :
		boss_health = value
		boss_new_health.emit(value)

var last_hit_perfect : bool = false
