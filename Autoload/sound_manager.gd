extends Node

@export var music: AudioStreamPlayer
@export var music_bus_name : String = "Music"

@export_group("Speed Brightness")
## Low-pass cutoff at zero speed ratio — how muffled the rally sounds at rest.
@export var muffled_cutoff_hz : float = 1400.0
## Cutoff once the ball is ignited or at max speed — fully open.
@export var bright_cutoff_hz : float = 20000.0
## Volume added at full speed, on top of the bus's base volume.
@export var speed_volume_bonus_db : float = 1.2
## Smoothing on the speed-tracked cutoff, so it doesn't jitter every frame.
@export var speed_smoothing : float = 6.0

@export_group("Ignition")
## Extra volume kick on top of the speed bonus while the ball is ignited.
@export var ignition_volume_bonus_db : float = 1.0
## How fast the cutoff sweeps fully open the instant the ball ignites.
@export var ignition_sweep_time : float = 0.15

@export_group("Hit Ducking")
## Floor the low-pass drops to on a hard duck (perfects, border hits).
@export var hit_duck_cutoff_hz : float = 900.0
## Volume reduction at full duck strength (perfects, border hits).
@export var hit_duck_volume_db : float = 8.0
@export var perfect_duck_recovery_time : float = 0.25
@export var border_hit_duck_recovery_time : float = 0.3
## Smashes only duck partway, and recover faster. 0 = no duck, 1 = full cut.
@export_range(0.0, 1.0) var smash_duck_strength : float = 0.25
@export var smash_duck_recovery_time : float = 0.15

@export_group("Damage Muffle")
@export var damage_muffle_cutoff_hz : float = 500.0
@export var damage_muffle_recovery_time : float = 0.5

@export_group("Ultimate")
## How quickly the duck lands when the ult starts, and how quickly it opens
## back up on impact. Real time — ignores the ult's own slow-mo.
@export var ult_duck_time : float = 0.08
@export var ult_recover_time : float = 0.08
## The low-pass does most of the "quieter" work here on purpose.
@export var ult_cutoff_hz : float = 500.0
## Kept modest — this is a duck, not a mute.
@export var ult_volume_db : float = 6.0

var _bus_index := -1
var _lowpass : AudioEffectLowPassFilter
var _base_volume_db : float = 0.0

var _speed_cutoff : float = 0.0
var _sweeping := false
var _ignited := false

## 0..1, tweened. 1 = fully ducked. Driven by paddle/border hits.
var _hit_duck := 0.0
## 0..1, tweened. 1 = fully muffled. Driven by taking damage.
var _damage_duck := 0.0
## 0..1, tweened. 1 = fully ducked (not silent). Driven by the ultimate.
var _ult_duck := 0.0

var _hit_tween : Tween
var _damage_tween : Tween
var _sweep_tween : Tween
var _ult_tween : Tween

func _ready() -> void:
	_bus_index = AudioServer.get_bus_index(music_bus_name)
	if _bus_index >= 0:
		_base_volume_db = AudioServer.get_bus_volume_db(_bus_index)
		_lowpass = AudioServer.get_bus_effect(_bus_index, 0) as AudioEffectLowPassFilter
	_speed_cutoff = muffled_cutoff_hz

	GameState.ult_started.connect(_on_ult_started)
	GameState.ult_impact.connect(_on_ult_impact)
	GameState.player_damaged.connect(_on_player_damaged)

## Ball registers itself with GameState after this (an autoload) is already
## ready, so it pushes the connection here instead of us pulling it.
func bind_ball(ball: Ball) -> void:
	ball.paddle_hit.connect(_on_paddle_hit)
	ball.border_hit.connect(_on_border_hit)
	ball.ignited_changed.connect(_on_ignited_changed)

func _process(delta: float) -> void:
	_update_speed_cutoff(delta)
	_push()

# --- Continuous speed brightness ---

func _update_speed_cutoff(delta: float) -> void:
	if _sweeping:
		return
	var ratio := 1.0 if _ignited else (GameState.ball.get_speed_ratio() if GameState.ball else 0.0)
	var target := lerpf(muffled_cutoff_hz, bright_cutoff_hz, ratio)
	var t := 1.0 - exp(-speed_smoothing * delta)
	_speed_cutoff = lerpf(_speed_cutoff, target, t)

func _speed_volume_bonus() -> float:
	var ratio := 1.0 if _ignited else (GameState.ball.get_speed_ratio() if GameState.ball else 0.0)
	return lerpf(0.0, speed_volume_bonus_db, ratio)

# --- Events ---

func _on_paddle_hit(paddle: Node2D) -> void:
	if paddle == null:
		return # Serve, not a real hit.
	if GameState.last_hit_perfect:
		_duck_hit(1.0, perfect_duck_recovery_time)
	elif GameState.last_hit_was_smash:
		_duck_hit(smash_duck_strength, smash_duck_recovery_time)
	# Taps: nothing.

func _on_border_hit(_border: Node2D, _damage: float) -> void:
	_duck_hit(1.0, border_hit_duck_recovery_time)

func _on_ignited_changed(ignited: bool) -> void:
	_ignited = ignited
	if ignited:
		_sweep_open()

func _on_ult_started(_character: GameState.Character) -> void:
	_tween_ult_duck(1.0, ult_duck_time)

func _on_ult_impact() -> void:
	_tween_ult_duck(0.0, ult_recover_time)

func _on_player_damaged() -> void:
	_duck_damage(1.0, damage_muffle_recovery_time)

# --- Duck / sweep helpers ---

func _duck_hit(strength: float, recovery_time: float) -> void:
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_duck = strength
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "_hit_duck", 0.0, recovery_time) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _duck_damage(strength: float, recovery_time: float) -> void:
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_duck = strength
	_damage_tween = create_tween()
	_damage_tween.tween_property(self, "_damage_duck", 0.0, recovery_time) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _sweep_open() -> void:
	if _sweep_tween and _sweep_tween.is_valid():
		_sweep_tween.kill()
	_sweeping = true
	_sweep_tween = create_tween()
	_sweep_tween.tween_property(self, "_speed_cutoff", bright_cutoff_hz, ignition_sweep_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sweep_tween.tween_callback(func(): _sweeping = false)

func _tween_ult_duck(target: float, time: float) -> void:
	if _ult_tween and _ult_tween.is_valid():
		_ult_tween.kill()
	_ult_tween = create_tween()
	_ult_tween.set_ignore_time_scale(true)
	_ult_tween.tween_property(self, "_ult_duck", target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- Push to the bus ---

func _push() -> void:
	if _bus_index < 0:
		return

	var cutoff := minf(_speed_cutoff, lerpf(bright_cutoff_hz, hit_duck_cutoff_hz, _hit_duck))
	cutoff = minf(cutoff, lerpf(bright_cutoff_hz, damage_muffle_cutoff_hz, _damage_duck))
	cutoff = minf(cutoff, lerpf(bright_cutoff_hz, ult_cutoff_hz, _ult_duck))
	if _lowpass:
		_lowpass.cutoff_hz = cutoff

	var volume := _base_volume_db + _speed_volume_bonus()
	if _ignited:
		volume += ignition_volume_bonus_db
	volume -= hit_duck_volume_db * _hit_duck
	volume -= ult_volume_db * _ult_duck
	AudioServer.set_bus_volume_db(_bus_index, volume)
