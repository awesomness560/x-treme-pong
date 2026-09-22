extends PanelContainer

## Small, non-interactive reminder of an upgrade you already have. Hover
## shows the full card as an animated popup owned by GameState.ui — grows
## in with a little overshoot, shrinks back out on exit.

@export var name_label: Label
@export var upgrade_theme : UpgradeTheme

var upgrade_script : Script
var rarity : GameState.UPGRADE_RARITY
var catagory : GameState.UPGRADE_CATAGORY

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Fills in this badge from a taken upgrade's script (same script objects
## the roll/pool system already deals in — see Upgrades.CATALOG).
func setup(script: Script) -> void:
	upgrade_script = script
	catagory = script.CATEGORY
	rarity = script.RARITY

	if name_label:
		name_label.text = script.DISPLAY_NAME
	_apply_theme()

func _apply_theme() -> void:
	if upgrade_theme == null:
		return
	if name_label:
		name_label.add_theme_color_override("font_color", Color.WHITE)
	add_theme_stylebox_override("panel", upgrade_theme.build_panel_style(get_theme_stylebox("panel"), rarity, catagory))

func _on_mouse_entered() -> void:
	if GameState.ui and upgrade_script:
		GameState.ui.show_upgrade_detail(upgrade_script, upgrade_theme, global_position + Vector2(0.0, size.y))

func _on_mouse_exited() -> void:
	if GameState.ui:
		GameState.ui.hide_upgrade_detail()
