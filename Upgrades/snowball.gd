class_name UpgradeSnowball
extends Upgrade

## Stays alive and reacts to every ignition for the rest of the run —
## permanent and ever-stacking, same shape as Ascendant.
const ID := "snowball"
const DISPLAY_NAME := "Snowball"
const DESCRIPTION := "Every ignition this round permanently adds +20% damage for the run."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["ignition", "damage", "trigger"]

const BONUS_PER_IGNITION := 0.2

func activate() -> void:
	GameState.ball.ignited_changed.connect(_on_ignited_changed)

func _on_ignited_changed(ignited: bool) -> void:
	if ignited:
		GameState.damage_bonus += BONUS_PER_IGNITION
