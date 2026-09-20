class_name UltBar
extends ColorRect

@export_group("Fill Animation")
## Seconds for a smash surge to reach its new value.
@export var surge_time: float = 0.18
## Seconds for a border or ignition jump. Slower and bigger.
@export var jump_time: float = 0.35
## Seconds for the ignition drip to catch up. Near-instant, it's continuous.
@export var drip_time: float = 0.08

@export_group("Flash")
@export var surge_flash: float = 0.5
@export var jump_flash: float = 1.0
@export var flash_decay: float = 0.3

@export_group("Armed")
@export var armed_pulse_speed: float = 1.6
@export var armed_pulse_depth: float = 0.35

@export_group("Firing")
@export var sweep_time: float = 0.45

var _displayed := 0.0
var _flash := 0.0
var _armed := 0.0
var _sweep := 0.0
var _pulse_phase := 0.0
var _fill_tween: Tween
var _flash_tween: Tween

func _ready() -> void:
	_displayed = GameState.ult_charge
	GameState.ult_gained.connect(_on_gained)
	GameState.ult_armed_changed.connect(_on_armed_changed)
	GameState.ult_spent.connect(_on_spent)
	_push()

func _process(delta: float) -> void:
	if GameState.ult_armed:
		_pulse_phase += delta * armed_pulse_speed * TAU
		var beat := 0.5 + 0.5 * sin(_pulse_phase)
		_armed = 1.0 - armed_pulse_depth * (1.0 - beat)
	_push()

func _on_gained(_amount: float, kind: GameState.GainKind) -> void:
	var time := surge_time
	var flash := surge_flash
	match kind:
		GameState.GainKind.SMASH:
			time = surge_time
			flash = surge_flash
		GameState.GainKind.IGNITION:
			# The continuous drip shouldn't flash every frame.
			time = drip_time if GameState.ball_ignited else jump_time
			flash = 0.0 if GameState.ball_ignited else jump_flash
		_:
			time = jump_time
			flash = jump_flash

	_animate_fill(time)
	if flash > 0.0:
		_do_flash(flash)

func _on_armed_changed(armed: bool) -> void:
	if armed:
		_pulse_phase = 0.0
		_armed = 1.0
		_do_flash(1.0)
	else:
		_armed = 0.0

func _on_spent() -> void:
	_armed = 0.0
	if _fill_tween and _fill_tween.is_valid():
		_fill_tween.kill()

	var tween := create_tween()
	tween.tween_property(self, "_sweep", 1.0, sweep_time) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_sweep = 0.0
		_displayed = 0.0)

func _animate_fill(time: float) -> void:
	if _fill_tween and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.tween_property(self, "_displayed", GameState.ult_charge, time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _do_flash(strength: float) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash = strength
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_flash", 0.0, flash_decay) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _push() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("fill", _displayed)
	mat.set_shader_parameter("rate", GameState.ult_rate)
	mat.set_shader_parameter("flash", _flash)
	mat.set_shader_parameter("sweep", _sweep)
	mat.set_shader_parameter("armed", _armed)
