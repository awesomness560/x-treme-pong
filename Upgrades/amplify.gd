class_name UpgradeAmplify
extends Upgrade

const ID := "amplify"
const DISPLAY_NAME := "Amplify"
const DESCRIPTION := "Ultimate damage +60%."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["ultimate", "damage"]

const BONUS := 0.6

func activate() -> void:
	GameState.ball.ult_damage_bonus += BONUS
