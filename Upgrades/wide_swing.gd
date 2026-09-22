class_name UpgradeWideSwing
extends Upgrade

const ID := "wide_swing"
const DISPLAY_NAME := "Wide Swing"
const DESCRIPTION := "Swing window +50%, perfect window +30%."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["smash", "perfect"]

func activate() -> void:
	GameState.paddle_flex.smash_window *= 1.5
	GameState.paddle_flex.perfect_window *= 1.3
