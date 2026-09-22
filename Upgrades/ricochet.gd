class_name UpgradeRicochet
extends Upgrade

const ID := "ricochet"
const DISPLAY_NAME := "Ricochet"
const DESCRIPTION := "Every wall bounce adds speed to the ball."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["wall", "speed"]

func activate() -> void:
	GameState.ball.wall_bounce_speed_gain += 100.0
