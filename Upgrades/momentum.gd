class_name UpgradeMomentum
extends Upgrade

const ID := "momentum"
const DISPLAY_NAME := "Momentum"
const DESCRIPTION := "Every hit adds extra speed, on top of what it already gains."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["speed"]

func activate() -> void:
	GameState.ball.extra_speed_per_hit += GameState.ball.tap_speed_gain
