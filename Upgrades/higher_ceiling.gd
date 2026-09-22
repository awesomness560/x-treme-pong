class_name UpgradeHigherCeiling
extends Upgrade

const ID := "higher_ceiling"
const DISPLAY_NAME := "Higher Ceiling"
const DESCRIPTION := "Tap speed cap +20%."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["tap", "speed"]

func activate() -> void:
	GameState.ball.tap_ceiling = minf(GameState.ball.tap_ceiling * 1.2, 1.0)
