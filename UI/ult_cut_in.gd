class_name UltCutIn
extends Control

@export var panel: Control          # The ColorRect with the panel shader
@export var voice: AudioStreamPlayer
@export var whoosh: AudioStreamPlayer

@export_group("Slide")
## How far off-screen it starts and ends, in screen heights.
@export var travel: float = 1.6
## Fraction of the duration spent entering.
@export_range(0.05, 0.45) var enter_fraction: float = 0.3
## Fraction spent leaving.
@export_range(0.05, 0.45) var exit_fraction: float = 0.3
## Speed lines rush this many pixels during the slide. 0 to disable.
@export var line_rush: float = 900.0

var _rest_position := Vector2.ZERO

func _ready() -> void:
	GameState.cut_in = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if panel:
		_rest_position = panel.position
		# Park it off-screen so it's never seen at rest.
		panel.position = _rest_position + _reach()

## Reads `slant` from the panel's shader, so the two can't drift apart.
func _slant() -> float:
	if panel == null:
		return 0.0
	var mat := panel.material as ShaderMaterial
	if mat == null:
		return 0.0
	var value = mat.get_shader_parameter("slant")
	return value if value != null else 0.0

## The off-screen offset, along the band's own diagonal.
func _reach() -> Vector2:
	var dir := Vector2(_slant(), 1.0).normalized()
	return dir * get_viewport_rect().size.y * travel

## Plays the cut-in over `duration` real seconds. Await this.
func play(duration: float) -> void:
	if panel == null:
		await _wait(duration)
		return

	var reach := _reach()
	panel.position = _rest_position + reach
	visible = true
	if whoosh:
		whoosh.play()
	if voice:
		voice.play()

	var enter := duration * enter_fraction
	var exit := duration * exit_fraction
	var hold := maxf(duration - enter - exit, 0.0)

	var tween := create_tween()
	tween.set_ignore_time_scale(true)

	tween.tween_property(panel, "position", _rest_position, enter) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	if line_rush != 0.0:
		tween.parallel().tween_method(_set_line_scroll, line_rush, 0.0, enter) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	tween.tween_interval(hold)

	tween.tween_property(panel, "position", _rest_position - reach, exit) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	if line_rush != 0.0:
		tween.parallel().tween_method(_set_line_scroll, 0.0, -line_rush, exit) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)

	await tween.finished

	visible = false
	panel.position = _rest_position + reach
	_set_line_scroll(0.0)

func stop() -> void:
	visible = false
	if panel:
		panel.position = _rest_position + _reach()
	_set_line_scroll(0.0)

func _set_line_scroll(value: float) -> void:
	if panel == null:
		return
	var mat := panel.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("line_scroll", value)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
