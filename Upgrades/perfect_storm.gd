class_name UpgradePerfectStorm
extends Upgrade

const ID := "perfect_storm"
const DISPLAY_NAME := "Perfect Storm"
const DESCRIPTION := "Perfect smashes at the speed cap deal quadruple damage."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["perfect", "speed", "damage"]

const MULTIPLIER := 4.0

func activate() -> void:
	GameState.ball.perfect_storm_damage_multiplier *= MULTIPLIER
