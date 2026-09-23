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

## Scaled up alongside ball.gd's new border-damage range (30-210 baseline) —
## the old value of 2.0 would now round to basically nothing.
const BASE_DAMAGE := 80.0

func activate() -> void:
	GameState.ball.ignited_changed.connect(_on_ignited_changed)

func _on_ignited_changed(ignited: bool) -> void:
	if not ignited:
		return
	var damage := GameState.deal_damage(BASE_DAMAGE * GameState.ball.get_speed_ratio())
	DamageNumbers.spawn(GameState.ball.global_position, damage)
