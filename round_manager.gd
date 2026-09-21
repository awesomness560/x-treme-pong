extends Node2D
class_name RoundManager

@export var round_wait_time: Timer

@export_group("Encounter")
@export var boss_scene : PackedScene
@export var border_scene : PackedScene
## How far off to the side the new boss/border start before sliding into
## place — positive x starts them to the right, matching the wipe's drift.
@export var spawn_offset : Vector2 = Vector2(400.0, 0.0)
@export var spawn_tween_time : float = 0.4

## Every boss/border should land back on the same spot the first one held.
var _boss_rest_position : Vector2
var _border_rest_position : Vector2

func _ready() -> void:
	GameState.boss_type = GameState.roll_next_boss_type()
	set_song()
	_boss_rest_position = GameState.enemy.global_position
	_border_rest_position = GameState.border.global_position

	round_wait_time.start()
	await round_wait_time.timeout
	GameState.ball.enter_and_serve()
	GameState.player_health_changed.connect(_player_health_changed)
	GameState.next_round.connect(_serve_after_wait)
	GameState.spawn_encounter.connect(_spawn_encounter)

func _player_health_changed():
	if GameState.player_health <= 0:
		return
	_serve_after_wait()

## The next boss/border are already in place by the time this fires (either
## after a point is lost, or once the round-transition wipe finishes).
func _serve_after_wait() -> void:
	GameState.ball.reset_to_entrance()
	round_wait_time.start()
	await round_wait_time.timeout
	GameState.ball.enter_and_serve()

## Fires while the transition line is off-screen, hidden from view. Once the
## line wipes back in, whatever's spawned here just plays normally — the
## boss's own AI and the border's own damage handling need no extra push.
func _spawn_encounter() -> void:
	# Rolled here so both the boss and border see the same new type in their
	# own _ready() before anything asks them to look right.
	GameState.boss_type = GameState.roll_next_boss_type()
	GameState._scale_round()
	set_song()
	_spawn_boss()
	_spawn_border()
	_spawn_gimmick()

func set_song():
	match GameState.boss_type:
		GameState.BossType.FIRE:
			SoundManager.music.set("parameters/switch_to_clip", &"fire")
		GameState.BossType.EARTH:
			SoundManager.music.set("parameters/switch_to_clip", &"earth")
		GameState.BossType.WATER:
			SoundManager.music.set("parameters/switch_to_clip", &"water")

## Instantiates the next boss off to the side and tweens it home.
func _spawn_boss() -> void:
	if boss_scene == null:
		return
	var boss := boss_scene.instantiate() as EnemyPaddle
	# Tell it not to fight the tween with its own positioning until settle().
	boss.entering = true
	add_child(boss)
	boss.global_position = _boss_rest_position + spawn_offset
	var tween := create_tween()
	tween.tween_property(boss, "global_position", _boss_rest_position, spawn_tween_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(boss.settle)

## Instantiates the next border off to the side and tweens it home.
func _spawn_border() -> void:
	if border_scene == null:
		return
	var border := border_scene.instantiate() as Border
	add_child(border)
	border.global_position = _border_rest_position + spawn_offset
	var tween := create_tween()
	tween.tween_property(border, "global_position", _border_rest_position, spawn_tween_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Stub: each boss type will eventually spawn its own gimmick scene here,
## keyed off GameState.boss_type. Not being built yet.
func _spawn_gimmick() -> void:
	pass
