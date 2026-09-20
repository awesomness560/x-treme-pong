class_name UpgradeLowFlashpoint
extends Upgrade

const ID := "low_flashpoint"
const DISPLAY_NAME := "Low Flashpoint"
const DESCRIPTION := "Ignition speed threshold -10%."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON

func activate() -> void:
	GameState.ball.ignite_min_ratio = maxf(GameState.ball.ignite_min_ratio - 0.1, 0.0)
