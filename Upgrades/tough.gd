class_name UpgradeTough
extends Upgrade

const ID := "tough"
const DISPLAY_NAME := "Tough"
const DESCRIPTION := "Max HP +1, and heal 1."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["health"]

func activate() -> void:
	GameState.max_player_health += 1
	GameState.player_health += 1
