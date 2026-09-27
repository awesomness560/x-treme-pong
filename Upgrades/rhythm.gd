class_name UpgradeRhythm
extends Upgrade

const ID := "rhythm"
const DISPLAY_NAME := "Rhythm"
const DESCRIPTION := "Each consecutive hit adds +12% damage, resetting when you hit the border."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["damage"]

const BONUS_PER_TAP := 0.12

func activate() -> void:
	GameState.ball.tap_streak_damage_bonus += BONUS_PER_TAP
