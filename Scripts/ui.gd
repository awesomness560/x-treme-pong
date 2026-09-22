extends CanvasLayer
class_name UI

@export var dotted_line: ColorRect

@export_group("Round Transition")
## How long each half of the wipe takes.
@export var slide_time: float = 0.35

@export_group("Upgrade Detail Popup")
## Scale it grows from — small overshoot past 1.0 on the way in reads as a
## little pop/settle rather than a flat linear grow.
@export_range(0.1, 1.0) var detail_scale_from : float = 0.7
@export var detail_show_time : float = 0.2
@export var detail_hide_time : float = 0.12
## Added to whatever anchor position the caller passes in, so the popup
## doesn't sit flush against the thing that triggered it.
@export var detail_offset : Vector2 = Vector2(0.0, 12.0)

var _dotted_line_rest_x: float = 0.0

const UPGRADE_CARD_SCENE := preload("res://UI/upgrade_card.tscn")
var _detail_card : UpgradeCard
var _detail_tween : Tween

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

# --- Upgrade detail popup ---
#
# A single shared, reused card that lives directly under this CanvasLayer —
# never inside any Container — so showing it on a badge's hover can never
# reflow that badge's siblings the way animating the badge's own layout
# size did before. Whoever wants one just hands us where to put it.

func _ensure_detail_card() -> UpgradeCard:
	if _detail_card == null:
		_detail_card = UPGRADE_CARD_SCENE.instantiate()
		_detail_card.animate_entrance = false
		_detail_card.hide()
		add_child(_detail_card)
		# _ready() (fired by add_child above) sets mouse_filter = STOP itself,
		# so this has to be set after — any earlier and _ready() clobbers it,
		# which is exactly what was making the popup steal hover from itself.
		_detail_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _detail_card

## `anchor_position` is wherever the caller wants the popup to hang off of
## (e.g. a badge's own global bottom-left corner) — detail_offset is added
## on top of that here, so callers don't need to know the gap themselves.
func show_upgrade_detail(script: Script, upgrade_theme: UpgradeTheme, anchor_position: Vector2) -> void:
	var card := _ensure_detail_card()
	card.upgrade_theme = upgrade_theme
	card.upgrade_name = script.DISPLAY_NAME
	card.description = script.DESCRIPTION
	card.catagory = script.CATEGORY
	card.rarity = script.RARITY
	card.refresh()
	# Not inside any Container, so nothing else will ever size this card to
	# fit its current text — has to be forced here or it stays whatever size
	# it last happened to be (usually whatever the .tscn saved).
	card.reset_size()

	var viewport_rect := get_viewport().get_visible_rect()
	var target := anchor_position + detail_offset
	target.x = clampf(target.x, 0.0, maxf(viewport_rect.size.x - card.size.x, 0.0))
	# Y is never adjusted — always landing detail_offset below the anchor is
	# what guarantees the popup can't overlap whatever you're hovering. A
	# badge near the bottom edge would otherwise get its own popup clamped
	# back up and over it.
	card.global_position = target
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2.ONE * detail_scale_from
	card.modulate.a = 0.0
	card.show()

	if _detail_tween and _detail_tween.is_valid():
		_detail_tween.kill()
	_detail_tween = create_tween()
	# Popups get triggered from badges shown while the pause menu has the
	# tree paused — this node isn't exempt from pause itself, so without this
	# the tween would freeze mid-animation instead of ever reaching its target.
	_detail_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_detail_tween.set_parallel(true)
	_detail_tween.tween_property(card, "scale", Vector2.ONE, detail_show_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_detail_tween.tween_property(card, "modulate:a", 1.0, detail_show_time)

func hide_upgrade_detail() -> void:
	if _detail_card == null or not _detail_card.visible:
		return
	var card := _detail_card

	if _detail_tween and _detail_tween.is_valid():
		_detail_tween.kill()
	_detail_tween = create_tween()
	_detail_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_detail_tween.set_parallel(true)
	_detail_tween.tween_property(card, "scale", Vector2.ONE * detail_scale_from, detail_hide_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_detail_tween.tween_property(card, "modulate:a", 0.0, detail_hide_time)
	_detail_tween.chain().tween_callback(card.hide)
