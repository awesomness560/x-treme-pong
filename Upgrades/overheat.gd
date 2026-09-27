class_name UpgradeOverheat
extends Upgrade

const ID := "overheat"
const DISPLAY_NAME := "Overheat"
const DESCRIPTION := "Above the ignition threshold, all damage +80%."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["speed", "damage"]

const BONUS := 0.8

func activate() -> void:
	GameState.ball.hot_damage_bonus += BONUS
