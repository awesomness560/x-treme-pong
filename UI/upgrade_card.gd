extends PanelContainer
class_name UpgradeCard

## Emitted on click, carrying the Upgrade script this card represents.
signal chosen(upgrade_script: Script)

@export var upgrade_name : String
@export var rarity : GameState.UPGRADE_RARITY
@export var catagory : GameState.UPGRADE_CATAGORY
@export var description : String
## The Upgrade-extending script to instantiate if this card gets picked.
@export var upgrade_script : Script
@export var upgrade_theme : UpgradeTheme
@export_group("Self references")
@export var catagory_label: Label
@export var rarity_label: Label
@export var name_label: Label
@export var description_label: Label
@export var top: HBoxContainer
## Pure layout spacing — must stay click-through, or it steals hover/click
## from the card underneath it. Forced to Ignore in _ready() either way.
@export var spacer: Control

@export_group("Animation")
## How far below its slot the card starts before sliding up into place.
@export var entrance_drop : float = 220.0
@export var entrance_time : float = 0.45
## Extra delay per stagger step — the caller passes its own index in.
@export var entrance_stagger : float = 0.08
@export var hover_scale : float = 1.08
@export var hover_time : float = 0.12
## Set false for uses that skip enter() entirely (e.g. a tooltip) — hiding
## on ready and waiting for enter() to reveal us would leave those blank.
@export var animate_entrance : bool = true

## The container-assigned slot position. The container owns `position`
## directly, so animation drives this offset on top of it instead — that
## way nothing fights the container's own layout pass.
var _base_position := Vector2.ZERO
var offset_position := Vector2.ZERO :
	set(value):
		offset_position = value
		position = _base_position + offset_position

var _entrance_tween : Tween
var _hover_tween : Tween

## Re-applies text/theme after changing the exported fields directly on an
## already-ready instance (e.g. a shared, reused detail popup) — _ready()
## only runs once, so a second use needs this instead.
func refresh() -> void:
	_apply_content()
	_apply_theme()

func _ready() -> void:
	_apply_content()
	_apply_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if spacer:
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if animate_entrance:
		# Hidden until enter() positions us — otherwise we'd flash at our
		# final spot for a frame before jumping down to start the animation.
		modulate.a = 0.0

## Call once every card in the row exists and the container has had a full
## frame to settle on final positions — capturing this any earlier (e.g. per
## card, right after its own _ready()) risks grabbing a stale slot, since
## the container reflows everyone's x as later siblings are still being added.
func enter(index: int) -> void:
	_base_position = position
	pivot_offset = size * 0.5
	offset_position = Vector2(0.0, entrance_drop)
	modulate.a = 1.0

	if _entrance_tween and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_entrance_tween = create_tween()
	_entrance_tween.tween_property(self, "offset_position", Vector2.ZERO, entrance_time) \
		.set_delay(index * entrance_stagger) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mouse_entered() -> void:
	_tween_scale(Vector2.ONE * hover_scale)

func _on_mouse_exited() -> void:
	_tween_scale(Vector2.ONE)

## Scale isn't container-managed, so this can just be tweened directly —
## no offset trick needed here, unlike position.
func _tween_scale(target: Vector2) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, hover_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(upgrade_script)

func _apply_content() -> void:
	if name_label:
		name_label.text = upgrade_name
	if description_label:
		description_label.text = description
	if catagory_label:
		catagory_label.text = GameState.UPGRADE_CATAGORY.keys()[catagory]

	var is_common := rarity == GameState.UPGRADE_RARITY.COMMON
	if rarity_label:
		rarity_label.visible = not is_common
		if not is_common:
			rarity_label.text = GameState.UPGRADE_RARITY.keys()[rarity]

func _apply_theme() -> void:
	if upgrade_theme == null:
		return
	var muted_color := upgrade_theme.muted_color(rarity, catagory)

	if catagory_label:
		catagory_label.add_theme_color_override("font_color", muted_color)
	if rarity_label:
		rarity_label.add_theme_color_override("font_color", muted_color)
	if description_label:
		description_label.add_theme_color_override("font_color", muted_color)
	if name_label:
		name_label.add_theme_color_override("font_color", Color.WHITE)

	var style := upgrade_theme.build_panel_style(get_theme_stylebox("panel"), rarity, catagory)
	add_theme_stylebox_override("panel", style)
