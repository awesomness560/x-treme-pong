class_name UpgradePierce
extends Upgrade

const ID := "pierce"
const DISPLAY_NAME := "Pierce"
const DESCRIPTION := "25% of smashes pass straight through the boss paddle."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["smash", "border"]

func activate() -> void:
	GameState.ball.pierce_chance += 0.25
