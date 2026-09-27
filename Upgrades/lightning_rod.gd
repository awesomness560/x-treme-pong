class_name UpgradeLightningRod
extends Upgrade

const ID := "lightning_rod"
const DISPLAY_NAME := "Lightning Rod"
const DESCRIPTION := "The first smash after any wall bounce deals +120% damage."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["wall", "smash", "damage"]

const BONUS := 1.2

func activate() -> void:
	GameState.ball.lightning_rod_bonus += BONUS
