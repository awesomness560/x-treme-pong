extends Node2D

## Stage sequencer for the tutorial. Uses the real Ball/Paddle/EnemyPaddle/
## Border nodes (same as round_manager.gd does for the main game) — this
## just drives which stage is active and when to move to the next one.
## The EnemyPaddle in this scene should have every miss-chance export
## (base_miss, speed_miss_max, smash_miss_max, distance_miss_max, etc.)
## zeroed out in the Inspector, so it always returns the ball here.

@export var tutorial_text: Label
@export var ult_bar: UltBar

enum Stage { RALLY, SMASH, PERFECT_SMASH, IGNITE, ULTIMATE, DONE }

@export_group("Rally Stage")
## Hits needed past this to clear "a rally above 3 hits".
@export var rally_hits_needed: int = 3

@export_group("Smash Stages")
@export var slow_serve_speed: float = 250.0
@export var wide_perfect_window: float = 0.35

@export_group("Ignite Stage")
@export var hot_serve_speed: float = 900.0

@export_group("Text")
@export var smash_prompt: String = "Press Left Mouse Button to SMASH"
@export var perfect_smash_prompt: String = "Press Left Mouse Button for a PERFECT SMASH"
@export var ignite_prompt: String = "SMASH while SMOKING to IGNITE"
@export var ultimate_prompt: String = "SMASH TO USE ULTIMATE"
@export var end_message: String = "Tutorial complete!"
@export var end_delay: float = 2.0

## How far past the player the ball has to get to count as a miss — just
## re-serves the current stage, never touches health or game over.
@export var miss_margin: float = 40.0

## Held on the completed prompt before the next stage's serve begins.
@export var stage_transition_delay: float = 2.0

var _stage := Stage.RALLY
var _rally_count := 0
var _default_perfect_window := 0.0

## True from the moment a stage clears until the next one actually starts —
## blocks the ball's own signals and the miss check so nothing double-fires
## while it's parked for stage_transition_delay.
var _transitioning := false

func _ready() -> void:
	tutorial_text.grow_horizontal = Control.GROW_DIRECTION_END
	GameState.reset_run()
	Upgrades.reset_run()

	GameState.ball.paddle_hit.connect(_on_paddle_hit)
	GameState.ball.ignited_changed.connect(_on_ignited_changed)
	GameState.take_damage.connect(_on_take_damage)
	# ult_ended (not ult_started) — that fires after the whole cut-in/charge/
	# launch cinematic resolves, so the stage doesn't cut the ult off early.
	GameState.ult_ended.connect(_on_ult_ended)

	if GameState.paddle_flex:
		_default_perfect_window = GameState.paddle_flex.perfect_window

	# The tutorial always force-arms the ult itself (see the ULTIMATE stage)
	# instead of waiting for real charge — without this, ordinary smashes,
	# perfects, ignitions, and the ignite stage's border hit legitimately
	# fill the bar and can arm (and fire) the ult in an earlier stage.
	GameState.ult_charge_manager.gain_multiplier = 0.0

	_start_stage(Stage.RALLY)

func _physics_process(_delta: float) -> void:
	_check_for_miss()

# --- Stage setup ---

func _start_stage(stage: Stage) -> void:
	_stage = stage
	_rally_count = 0

	match stage:
		Stage.RALLY:
			_set_text("Move your mouse")
			_serve(-1.0, _side_toward_player())
		Stage.SMASH:
			_set_text(smash_prompt)
			_serve(slow_serve_speed, _side_toward_player())
		Stage.PERFECT_SMASH:
			if GameState.paddle_flex:
				GameState.paddle_flex.perfect_window = wide_perfect_window
			_set_text(perfect_smash_prompt)
			_serve(slow_serve_speed, _side_toward_player())
		Stage.IGNITE:
			_set_text(ignite_prompt)
			_serve(hot_serve_speed, _side_toward_boss())
		Stage.ULTIMATE:
			ult_bar.show()
			GameState.ult_charge_manager.arm()
			_set_text(ultimate_prompt)
			_serve(-1.0, _side_toward_player())

func _serve(speed: float, side: float) -> void:
	GameState.ball.reset_to_entrance()
	GameState.ball.enter_and_serve(speed, side)

func _side_toward_player() -> float:
	return signf(GameState.player.global_position.x - GameState.enemy.global_position.x)

func _side_toward_boss() -> float:
	return -_side_toward_player()

# --- Progress ---

func _on_paddle_hit(paddle: Node2D) -> void:
	if _transitioning or paddle != GameState.player:
		return

	match _stage:
		Stage.RALLY:
			_rally_count += 1
			if _rally_count > rally_hits_needed:
				_advance()
		Stage.SMASH:
			if GameState.last_hit_was_smash:
				_advance()
		Stage.PERFECT_SMASH:
			if GameState.last_hit_was_smash and GameState.last_hit_perfect:
				_advance()

## The ignited hit itself only arms the guaranteed miss that lets the shot
## reach the border — the stage doesn't actually clear until that hit lands
## (see _on_take_damage), so the player gets to see the score.
func _on_ignited_changed(ignited: bool) -> void:
	if _transitioning:
		return
	if ignited and _stage == Stage.IGNITE and GameState.enemy:
		GameState.enemy.force_miss_next = true

func _on_take_damage(_amount: float) -> void:
	if not _transitioning and _stage == Stage.IGNITE:
		_advance()

func _on_ult_ended() -> void:
	if not _transitioning and _stage == Stage.ULTIMATE:
		_advance()

## Holds the completed prompt for stage_transition_delay before moving on —
## the ball is left alone and stays in play the whole time (see
## _transitioning's doc comment), it's only reset once the next stage
## actually serves.
func _advance() -> void:
	if _transitioning:
		return
	_transitioning = true
	await get_tree().create_timer(stage_transition_delay).timeout
	_transitioning = false

	match _stage:
		Stage.RALLY:
			_start_stage(Stage.SMASH)
		Stage.SMASH:
			_start_stage(Stage.PERFECT_SMASH)
		Stage.PERFECT_SMASH:
			if GameState.paddle_flex:
				GameState.paddle_flex.perfect_window = _default_perfect_window
			_start_stage(Stage.IGNITE)
		Stage.IGNITE:
			_start_stage(Stage.ULTIMATE)
		Stage.ULTIMATE:
			_finish()

# --- Miss handling ---

func _check_for_miss() -> void:
	if _transitioning or _stage == Stage.DONE:
		return
	var ball := GameState.ball
	if not ball.in_play:
		return
	# Past the player, on the side away from the boss — same test as
	# player_lose.gd's lose-zone would catch, just without touching health.
	var past := (ball.global_position.x - GameState.player.global_position.x) * _side_toward_boss()
	if past < -miss_margin:
		_start_stage(_stage) # Same stage again, no penalty.

# --- Ending ---

func _finish() -> void:
	_stage = Stage.DONE
	_set_text(end_message)
	await get_tree().create_timer(end_delay).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")

func _set_text(text: String) -> void:
	if tutorial_text:
		tutorial_text.text = text
