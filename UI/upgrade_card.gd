extends PanelContainer

## Emitted on click, carrying the Upgrade script this card represents.
signal chosen(upgrade_script: Script)

@export var upgrade_name : String
@export var rarity : GameState.UPGRADE_RARITY
@export var catagory : GameState.UPGRADE_CATAGORY
@export var description : String
## The Upgrade-extending script to instantiate if this card gets picked.
@export var upgrade_script : Script
@export_group("Self references")
@export var catagory_label: Label
@export var rarity_label: Label
@export var name_label: Label
@export var description_label: Label

@export_group("Theming")
## How far the muted text/background color slides toward white.
@export_range(0.0, 1.0) var dilution_amount : float = 0.55
@export_range(0.0, 1.0) var background_alpha : float = 0.16
@export var border_width_common : int = 2
@export var border_width_rare : int = 4
@export var border_width_legendary : int = 6
@export_subgroup("Rarity Colors")
## Rarity is the only thing that colors the card (Heal is the one exception).
@export var common_color : Color = Color(1.0, 1.0, 1.0)
@export var rare_color : Color = Color(0.3, 0.85, 1.3)
@export var legendary_color : Color = Color(1.3, 1.0, 0.25)

## Plain-common's muted text/background tone. Lerping white toward white stays
## white, so this needs its own flat gray rather than the usual dilution.
const COMMON_MUTED_COLOR := Color(0.6, 0.6, 0.6)

## The player paddle's current color, HDR-boosted for bloom. Heal always uses
## this (luminance stripped out below) instead of a rarity color.
const PADDLE_COLOR := Color(1.572, 0.308, 0.852)

@export_group("Animation")
## How far below its slot the card starts before sliding up into place.
@export var entrance_drop : float = 220.0
@export var entrance_time : float = 0.45
## Extra delay per stagger step — the caller passes its own index in.
@export var entrance_stagger : float = 0.08
@export var hover_scale : float = 1.08
@export var hover_time : float = 0.12

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

func _ready() -> void:
	_apply_content()
	_apply_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# Hidden until enter() positions us — otherwise we'd flash at our final
	# spot for a frame before jumping down to start the animation.
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
	# Heal always uses the paddle color, whatever rarity it's nominally given.
	var is_plain_common := rarity == GameState.UPGRADE_RARITY.COMMON \
		and catagory != GameState.UPGRADE_CATAGORY.HEAL
	var border_color := _resolve_color()
	var muted_color := COMMON_MUTED_COLOR if is_plain_common \
		else border_color.lerp(Color.WHITE, dilution_amount)

	if catagory_label:
		catagory_label.add_theme_color_override("font_color", muted_color)
	if rarity_label:
		rarity_label.add_theme_color_override("font_color", muted_color)
	if description_label:
		description_label.add_theme_color_override("font_color", muted_color)
	if name_label:
		name_label.add_theme_color_override("font_color", Color.WHITE)

	var base_style := get_theme_stylebox("panel")
	var style : StyleBoxFlat = base_style.duplicate() if base_style is StyleBoxFlat \
		else StyleBoxFlat.new()
	style.border_color = border_color
	style.bg_color = Color(muted_color.r, muted_color.g, muted_color.b, background_alpha)
	var width := _border_width()
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width
	add_theme_stylebox_override("panel", style)

func _border_width() -> int:
	# Heal's only exceptions are its color and this: always Rare's thickness.
	if catagory == GameState.UPGRADE_CATAGORY.HEAL:
		return border_width_rare
	match rarity:
		GameState.UPGRADE_RARITY.LEGENDARY:
			return border_width_legendary
		GameState.UPGRADE_RARITY.RARE:
			return border_width_rare
		_:
			return border_width_common

func _resolve_color() -> Color:
	if catagory == GameState.UPGRADE_CATAGORY.HEAL:
		return _strip_luminance(PADDLE_COLOR)
	match rarity:
		GameState.UPGRADE_RARITY.LEGENDARY:
			return legendary_color
		GameState.UPGRADE_RARITY.RARE:
			return rare_color
		_:
			return common_color

## Scales the color down so its brightest channel is exactly 1.0, removing
## any bloom-driving overbright boost while keeping the hue.
static func _strip_luminance(color: Color) -> Color:
	var peak := maxf(color.r, maxf(color.g, color.b))
	if peak <= 1.0:
		return color
	return Color(color.r / peak, color.g / peak, color.b / peak, color.a)
