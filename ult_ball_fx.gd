class_name UltBallFX
extends Node2D

@export var character: GameState.Character = GameState.Character.PINK

@export_group("Fire Build")
## The colour the ball turns during the charge.
@export var ult_color: Color = Color(4.0, 1.4, 0.2)
## How much the ball swells at full charge.
@export var max_scale: float = 1.6
@export var fire: GPUParticles2D
@export var sparks: GPUParticles2D

@export_group("Audio")
@export var charge_sound: AudioStreamPlayer
@export var launch_sound: AudioStreamPlayer

var _sprite: Sprite2D
var _base_color := Color.WHITE
var _base_scale := Vector2.ONE
var _active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Runs at real speed in slow-mo.
	GameState.ult_started.connect(_on_started)
	GameState.ult_charge_progress.connect(_on_progress)
	GameState.ult_launched.connect(_on_launched)
	_set_emitting(false)

func _process(_delta: float) -> void:
	if _active and _sprite:
		global_position = _sprite.global_position

func _on_started(who: GameState.Character) -> void:
	if who != character:
		return
	var ball := GameState.ball
	if ball == null:
		return

	# The break is the real end of the effect.
	ball.border_broken.connect(_on_impact, CONNECT_ONE_SHOT)

	_sprite = ball.sprite
	if _sprite:
		_base_color = _sprite.modulate
		_base_scale = _sprite.scale
		global_position = _sprite.global_position

	_active = true
	_set_emitting(true)
	if charge_sound:
		charge_sound.play()

## t goes 0 to 1 across the charge phase, in real seconds.
func _on_progress(t: float) -> void:
	if not _active or _sprite == null:
		return

	# Ease so the fire catches late and hard rather than linearly.
	var e := t * t

	_sprite.modulate = _base_color.lerp(ult_color, e)
	_sprite.scale = _base_scale * lerpf(1.0, max_scale, e)

	if fire:
		fire.amount_ratio = clampf(e, 0.05, 1.0)
	if sparks:
		sparks.amount_ratio = clampf(e * e, 0.0, 1.0)

func _on_launched() -> void:
	if not _active:
		return
	if launch_sound:
		launch_sound.play()
	if charge_sound:
		charge_sound.stop()
	# Fire stays on for the flight.

func _on_impact(_border: Node2D, _damage: float) -> void:
	# Burst goes here later.
	_restore()

func _restore() -> void:
	if not _active:
		return
	_active = false
	_set_emitting(false)
	if _sprite:
		_sprite.modulate = _base_color
		_sprite.scale = _base_scale
	_sprite = null

func _set_emitting(value: bool) -> void:
	if fire:
		fire.emitting = value
	if sparks:
		sparks.emitting = value
