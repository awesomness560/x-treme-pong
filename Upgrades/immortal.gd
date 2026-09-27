class_name UpgradeImmortal
extends Upgrade

const ID := "immortal"
const DISPLAY_NAME := "Immortal"
const DESCRIPTION := "HP +3"
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["health", "risk"]

const MAX_HP_GAIN := 3

func activate() -> void:
	GameState.max_player_health += MAX_HP_GAIN
	GameState.player_health += MAX_HP_GAIN
	GameState.healing_blocked = true
