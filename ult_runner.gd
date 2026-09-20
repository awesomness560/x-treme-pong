class_name UltRunner
extends Node

signal finished()

@export_group("Timing")
## Phase 1: the character cut-in.
@export var cut_in_time: float = 1.2
## Phase 2: the ball charging up.
@export var charge_time: float = 0.8
## Time scale for the world during phases 1 and 2.
@export_range(0.01, 1.0) var slow_scale: float = 0.1

var is_running := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.ult_runner = self

## Fire the ult. Returns false if it couldn't.
func activate() -> bool:
	if is_running:
		return false
	var charge := GameState.ult_charge_manager
	if charge == null or not charge.spend():
		return false
	_run()
	return true

func _run() -> void:
	is_running = true
	GameState.ult_active = true
	GameState.input_locked = true
	Engine.time_scale = slow_scale

	if GameState.ball:
		GameState.ball.begin_ult()
	GameState.ult_started.emit(GameState.character)

	# --- Phase 1: cut-in ---
	var cut_in := GameState.cut_in
	if cut_in:
		await cut_in.play(cut_in_time)
	else:
		await _wait_real(cut_in_time)

	# --- Phase 2: charge. Real seconds, read off a real clock. ---
	var start := Time.get_ticks_usec()
	var elapsed := 0.0
	while elapsed < charge_time:
		await get_tree().process_frame
		elapsed = float(Time.get_ticks_usec() - start) / 1_000_000.0
		GameState.ult_charge_progress.emit(clampf(elapsed / charge_time, 0.0, 1.0))
	GameState.ult_charge_progress.emit(1.0)

	# --- Phase 3: launch. The ball and the FX own the rest. ---
	Engine.time_scale = 1.0
	GameState.camera_shook.emit(1.3)
	GameState.input_locked = false
	if GameState.ball:
		GameState.ball.launch_ult()
	GameState.ult_launched.emit()

	_end()

func _end() -> void:
	is_running = false
	GameState.ult_active = false
	GameState.ult_ended.emit()
	finished.emit()

## Abort cleanly, for a scene change or a death mid-ult.
func cancel() -> void:
	if not is_running:
		return
	Engine.time_scale = 1.0
	GameState.input_locked = false
	if GameState.ult_cut_in:
		GameState.ult_cut_in.stop()
	if GameState.ball:
		GameState.ball.cancel_ult()
	_end()

func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
