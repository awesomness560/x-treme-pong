class_name HealthBar
extends ColorRect

signal segments_broken(indices: Array[int], centers: Array[Vector2])

@export var segment_count: int = 10
@export var slant: float = 0.4
@export var reverse: bool = false
## How long the shatter animation takes.
@export var break_time: float = 0.45
@export var break_particles: GPUParticles2D

@export_group("Shake")
## Shake distance in pixels for losing a single segment.
@export var shake_base: float = 4.0
## Extra pixels per additional segment lost in one hit.
@export var shake_per_segment: float = 2.5
@export var shake_max: float = 18.0
@export var shake_time: float = 0.18
## Shakes per second. Higher is buzzier.
@export var shake_frequency: float = 38.0
@export_range(0.0, 1.0) var shake_vertical: float = 0.45

var _health := 1.0
var _break_low := -1   # Lowest segment index shattering.
var _break_high := -1  # Highest segment index shattering.
var _break_progress := 0.0
var _break_tween: Tween

var _base_offset := Vector2.ZERO
var _shake_strength := 0.0
var _shake_elapsed := 0.0
var _shake_tween: Tween

func _ready() -> void:
	_base_offset = position
	_push_uniforms()
	GameState.boss_new_health.connect(set_health)

## Call this when the boss takes damage. 0 to 1.
func set_health(value: float) -> void:
	var new_health := clampf(value, 0.0, 1.0)
	if is_equal_approx(new_health, _health):
		return

	var old_health := _health
	_health = new_health
	_push_uniforms()

	if new_health < old_health:
		_shatter_range(old_health, new_health)

# --- Shatter ---

## Shatters every segment that went from having fill to having none.
func _shatter_range(from_health: float, to_health: float) -> void:
	var high := ceili(from_health * segment_count) - 1
	var low := ceili(to_health * segment_count)
	if high < low:
		return

	if _break_tween and _break_tween.is_valid():
		_break_tween.kill()

	_break_low = low
	_break_high = high
	_break_progress = 0.0

	var indices: Array[int] = []
	var centers: Array[Vector2] = []
	for i in range(high, low - 1, -1):
		indices.append(i)
		centers.append(_segment_center(i))

	segments_broken.emit(indices, centers)
	if break_particles and not centers.is_empty():
		# Burst from the middle of the broken run.
		break_particles.position = (centers[0] + centers[-1]) * 0.5
		break_particles.restart()

	_start_shake(indices.size())

	_break_tween = create_tween()
	_break_tween.tween_property(self, "_break_progress", 1.0, break_time)
	_break_tween.tween_callback(_clear_break)

func _clear_break() -> void:
	_break_low = -1
	_break_high = -1
	_push_uniforms()

# --- Shake ---

func _start_shake(segments_lost: int) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_strength = minf(shake_base + shake_per_segment * (segments_lost - 1), shake_max)
	_shake_elapsed = 0.0

	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "_shake_strength", 0.0, shake_time) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_callback(func(): position = _base_offset)

# --- Per-frame ---

func _process(delta: float) -> void:
	if _break_low >= 0:
		_push_uniforms()

	if _shake_strength > 0.01:
		_shake_elapsed += delta
		var t := _shake_elapsed * shake_frequency
		# Two frequencies so it doesn't read as a clean sine wave.
		var x := sin(t) * 0.7 + sin(t * 2.3) * 0.3
		var y := cos(t * 1.7) * shake_vertical
		position = _base_offset + Vector2(x, y) * _shake_strength

func _push_uniforms() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("health", _health)
	mat.set_shader_parameter("segment_count", segment_count)
	mat.set_shader_parameter("slant", slant)
	mat.set_shader_parameter("reverse", reverse)
	mat.set_shader_parameter("break_low", _break_low)
	mat.set_shader_parameter("break_high", _break_high)
	mat.set_shader_parameter("break_progress", _break_progress)

func _segment_center(index: int) -> Vector2:
	var margin := absf(slant) * size.y * 0.5
	var usable := maxf(size.x - margin * 2.0, 1.0)
	var slot := usable / float(segment_count)
	var x := (index + 0.5) * slot
	if reverse:
		x = usable - x
	# The shear is zero on the vertical midline, so no slant correction here.
	return Vector2(margin + x, size.y * 0.5)
