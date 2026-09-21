extends CanvasLayer
class_name UI

@export var dotted_line: ColorRect

@export_group("Round Transition")
## How long each half of the wipe takes.
@export var slide_time: float = 0.35

var _dotted_line_rest_x: float = 0.0

func _ready() -> void:
	GameState.ui = self
	if dotted_line:
		_dotted_line_rest_x = dotted_line.position.x
	GameState.start_round.connect(_on_start_round)

## The full "moving forward" beat: wipe the center line off-screen left,
## spawn the next encounter while it's off-screen, wipe it back in from the
## right. GameState.next_round tells whoever serves that it's safe to go.
func _on_start_round() -> void:
	GameState.input_locked = true
	await _slide_line_out()
	GameState.spawn_encounter.emit()
	await _slide_line_in()
	GameState.input_locked = false
	GameState.next_round.emit()

func _slide_line_out() -> void:
	if dotted_line == null:
		return
	var tween := create_tween()
	tween.tween_property(dotted_line, "position:x", -dotted_line.size.x, slide_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	# Teleport the instant it's fully gone: reappear queued up on the right.
	dotted_line.position.x = get_viewport().get_visible_rect().size.x

func _slide_line_in() -> void:
	if dotted_line == null:
		return
	var tween := create_tween()
	tween.tween_property(dotted_line, "position:x", _dotted_line_rest_x, slide_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
