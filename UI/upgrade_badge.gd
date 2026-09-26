extends PanelContainer

## Small, non-interactive reminder of an upgrade you already have. Hover
## shows the full card as a native tooltip instead of spawning its own —
## Godot owns the popup, we just hand it the content.

@export var name_label: Label
@export var upgrade_theme : UpgradeTheme

const UPGRADE_CARD_SCENE := preload("res://UI/upgrade_card.tscn")

var upgrade_script : Script
var rarity : GameState.UPGRADE_RARITY
var catagory : GameState.UPGRADE_CATAGORY

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

## Fills in this badge from a taken upgrade's script (same script objects
## the roll/pool system already deals in — see Upgrades.CATALOG).
func setup(script: Script) -> void:
	upgrade_script = script
	catagory = script.CATEGORY
	rarity = script.RARITY

	if name_label:
		name_label.text = script.DISPLAY_NAME
	_apply_theme()
	# Godot only calls _make_custom_tooltip() when tooltip_text is non-empty
	# — the actual content comes from that override below, this just has to
	# be non-empty to trigger it.
	tooltip_text = script.DISPLAY_NAME

func _apply_theme() -> void:
	if upgrade_theme == null:
		return
	if name_label:
		name_label.add_theme_color_override("font_color", Color.WHITE)
	add_theme_stylebox_override("panel", upgrade_theme.build_panel_style(get_theme_stylebox("panel"), rarity, catagory))

## Native tooltip override: a plain UpgradeCard, filled in and handed to
## Godot's own tooltip popup instead of anything we manage ourselves.
func _make_custom_tooltip(_for_text: String) -> Control:
	if upgrade_script == null:
		return null
	var card := UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
	card.animate_entrance = false
	card.upgrade_theme = upgrade_theme
	card.upgrade_name = upgrade_script.DISPLAY_NAME
	card.description = upgrade_script.DESCRIPTION
	card.catagory = upgrade_script.CATEGORY
	card.rarity = upgrade_script.RARITY
	# The card's own size flags are tuned for living inside the upgrade-
	# choice menu's HBoxContainer (Fill, so all offered cards share a row
	# height) — there's no such container here to constrain that against,
	# so left alone it expands to the tooltip popup's provisional size
	# instead of shrinking to its own content. Force shrink-to-content.
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return card
