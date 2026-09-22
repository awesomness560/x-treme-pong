class_name UpgradeKindle
extends Upgrade

const ID := "kindle"
const DISPLAY_NAME := "Kindle"
const DESCRIPTION := "Meter gain +50%."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["ultimate"]

func activate() -> void:
	GameState.ult_charge_manager.gain_multiplier *= 1.5
