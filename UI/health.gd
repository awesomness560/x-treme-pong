class_name Heart
extends ColorRect

signal lost_finished

@export var particles: GPUParticles2D

@export_group("Idle Pulse")
## Scale added at the peak of the beat.
@export var pulse_amount: float = 0.06
## Beats per second.
@export var pulse_speed: float = 1.1

@export_group("Loss")
## Quick scale-up before it goes.
@export var pop_scale: float = 1.35
@export var pop_time: float = 0.12
## Hang time at the top, so the loss registers.
@export var hang_time: float = 0.1
@export var fade_time: float = 0.35

var is_lost := false

var _pulse_phase := 0.0
var _tween: Tween

func _ready() -> void:
	_center_pivot()
	resized.connect(_center_pivot)
	_pulse_phase = randf() * TAU # So a row doesn't beat in lockstep.

func _process(delta: float) -> void:
	if is_lost:
		return
	_pulse_phase += delta * pulse_speed * TAU
	# Sharp rise, slow fall: a heartbeat rather than a sine.
	var beat := pow(maxf(sin(_pulse_phase), 0.0), 3.0)
	scale = Vector2.ONE * (1.0 + beat * pulse_amount)

## Play the loss: pop, hang, puff, fade.
func lose() -> void:
	if is_lost:
		return
	is_lost = true
	_kill_tween()

	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * pop_scale, pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hang_time)
	_tween.tween_callback(_emit_particles)
	_tween.tween_property(self, "modulate:a", 0.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.7, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): lost_finished.emit())

## Pop back in, for a gained heart.
func gain() -> void:
	_kill_tween()
	is_lost = false
	modulate.a = 1.0
	scale = Vector2.ONE * 0.4

	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * pop_scale, pop_time * 1.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, pop_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Set the state with no animation, for setup.
func set_lost(value: bool) -> void:
	_kill_tween()
	is_lost = value
	scale = Vector2.ONE
	modulate.a = 0.0 if value else 1.0

func _center_pivot() -> void:
	pivot_offset_ratio = Vector2(0.5, 0.5)

func _emit_particles() -> void:
	if particles:
		#var global_pos = particles.global_position
		#particles.reparent(get_tree().current_scene, true)
		#particles.global_position = global_pos
		particles.emitting = true
		#particles.finished.connect(particles.queue_free)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
