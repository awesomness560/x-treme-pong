class_name UpgradeHeavyHand
extends Upgrade

const ID := "heavy_hand"
const DISPLAY_NAME := "Heavy Hand"
const DESCRIPTION := "Smash damage multiplier +15%."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["smash", "damage"]

func activate() -> void:
	GameState.ball.smash_factor *= 1.15
