class_name UpgradeLowFlashpoint
extends Upgrade

const ID := "low_flashpoint"
const DISPLAY_NAME := "Low Flashpoint"
const DESCRIPTION := "Ignition threshold -40%."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["ignition", "enabler"]

const MULTIPLIER := 0.6

func activate() -> void:
	GameState.ball.ignite_min_ratio *= MULTIPLIER
