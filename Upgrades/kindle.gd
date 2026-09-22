class_name UpgradeKindle
extends Upgrade

const ID := "kindle"
const DISPLAY_NAME := "Kindle"
const DESCRIPTION := "Meter gain from smashes +20%."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["ultimate", "perfect"]

func activate() -> void:
	GameState.ult_charge_manager.smash_low *= 1.2
	GameState.ult_charge_manager.smash_high *= 1.2
	GameState.ult_charge_manager.perfect_high *= 1.2
