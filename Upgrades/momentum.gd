class_name UpgradeMomentum
extends Upgrade

const ID := "momentum"
const DISPLAY_NAME := "Momentum"
const DESCRIPTION := "Taps add 2x more speed."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["tap", "speed"]

func activate() -> void:
	GameState.ball.tap_speed_gain *= 2.0
