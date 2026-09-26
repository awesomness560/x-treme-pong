class_name UpgradeRhythm
extends Upgrade

const ID := "rhythm"
const DISPLAY_NAME := "Rhythm"
const DESCRIPTION := "Each consecutive tap adds +12% tap damage, resetting when you smash."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["tap", "damage"]

const BONUS_PER_TAP := 0.12

func activate() -> void:
	GameState.ball.tap_streak_damage_bonus += BONUS_PER_TAP
