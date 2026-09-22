class_name UpgradeLastStand
extends Upgrade

const ID := "last_stand"
const DISPLAY_NAME := "Last Stand"
const DESCRIPTION := "Survive one lethal hit per run."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["health", "ultimate", "risk"]

func activate() -> void:
	GameState.grant_last_stand()
