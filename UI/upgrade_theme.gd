class_name UpgradeTheme
extends Resource

## Shared by every place an upgrade gets drawn (the pickable menu card, the
## small reminder badge, anything later) so retuning a color or border width
## only ever needs touching one .tres, not every consumer individually.

## How far the muted text/background color slides toward white.
@export_range(0.0, 1.0) var dilution_amount : float = 0.55
@export_range(0.0, 1.0) var background_alpha : float = 0.16
@export var border_width_common : int = 2
@export var border_width_rare : int = 4
@export var border_width_legendary : int = 6

@export_group("Rarity Colors")
## Rarity is the only thing that colors a card (Heal is the one exception).
@export var common_color : Color = Color(1.0, 1.0, 1.0)
@export var rare_color : Color = Color(0.3, 0.85, 1.3)
@export var legendary_color : Color = Color(1.3, 1.0, 0.25)

## Plain-common's muted text/background tone. Lerping white toward white stays
## white, so this needs its own flat gray rather than the usual dilution.
const COMMON_MUTED_COLOR := Color(0.6, 0.6, 0.6)

## The player paddle's current color, HDR-boosted for bloom. Heal always uses
## this (luminance stripped out below) instead of a rarity color.
const PADDLE_COLOR := Color(1.572, 0.308, 0.852)

func resolve_color(rarity: GameState.UPGRADE_RARITY, catagory: GameState.UPGRADE_CATAGORY) -> Color:
	if catagory == GameState.UPGRADE_CATAGORY.HEAL:
		return _strip_luminance(PADDLE_COLOR)
	match rarity:
		GameState.UPGRADE_RARITY.LEGENDARY:
			return legendary_color
		GameState.UPGRADE_RARITY.RARE:
			return rare_color
		_:
			return common_color

func muted_color(rarity: GameState.UPGRADE_RARITY, catagory: GameState.UPGRADE_CATAGORY) -> Color:
	# Heal always uses the paddle color, whatever rarity it's nominally given.
	var is_plain_common := rarity == GameState.UPGRADE_RARITY.COMMON \
		and catagory != GameState.UPGRADE_CATAGORY.HEAL
	if is_plain_common:
		return COMMON_MUTED_COLOR
	return resolve_color(rarity, catagory).lerp(Color.WHITE, dilution_amount)

func border_width(rarity: GameState.UPGRADE_RARITY, catagory: GameState.UPGRADE_CATAGORY) -> int:
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

## Duplicates `base_style` (so the caller's own corner radius/shadow survive)
## and applies this rarity's border/background on top of it.
func build_panel_style(base_style: StyleBox, rarity: GameState.UPGRADE_RARITY,
		catagory: GameState.UPGRADE_CATAGORY) -> StyleBoxFlat:
	var style : StyleBoxFlat = base_style.duplicate() if base_style is StyleBoxFlat \
		else StyleBoxFlat.new()
	var border_color := resolve_color(rarity, catagory)
	var muted := muted_color(rarity, catagory)
	style.border_color = border_color
	style.bg_color = Color(muted.r, muted.g, muted.b, background_alpha)
	var width := border_width(rarity, catagory)
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width
	return style

## Scales the color down so its brightest channel is exactly 1.0, removing
## any bloom-driving overbright boost while keeping the hue.
static func _strip_luminance(color: Color) -> Color:
	var peak := maxf(color.r, maxf(color.g, color.b))
	if peak <= 1.0:
		return color
	return Color(color.r / peak, color.g / peak, color.b / peak, color.a)
