class_name UpgradeCombustion
extends Upgrade

## Stays alive and reacts to ignition for the rest of the run, rather than
## doing a one-shot stat change on pick.
const ID := "combustion"
const DISPLAY_NAME := "Combustion"
const DESCRIPTION := "Igniting the ball instantly damages the border, scaled by speed."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["ignition", "border", "damage"]

const BASE_DAMAGE := 2.0

func activate() -> void:
	GameState.ball.ignited_changed.connect(_on_ignited_changed)

func _on_ignited_changed(ignited: bool) -> void:
	if not ignited:
		return
	GameState.deal_damage(BASE_DAMAGE * GameState.ball.get_speed_ratio())
