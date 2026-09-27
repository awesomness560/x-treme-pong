class_name UpgradeTinder
extends Upgrade

## Stays alive and reacts to ignition — round_ignited_damage_bonus resets
## itself every round, so this just keeps adding to it as ignitions happen.
const ID := "tinder"
const DISPLAY_NAME := "Tinder"
const DESCRIPTION := "Each ignition this round adds +15% ignited damage, for the round."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["ignition", "damage", "stack"]

const BONUS_PER_IGNITION := 0.15

func activate() -> void:
	GameState.ball.ignited_changed.connect(_on_ignited_changed)

func _on_ignited_changed(ignited: bool) -> void:
	if ignited:
		GameState.round_ignited_damage_bonus += BONUS_PER_IGNITION
