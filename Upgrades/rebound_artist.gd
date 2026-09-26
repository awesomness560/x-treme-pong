class_name UpgradeReboundArtist
extends Upgrade

const ID := "rebound_artist"
const DISPLAY_NAME := "Rebound Artist"
const DESCRIPTION := "Shots that bounce off a wall before reaching the border deal +75% damage."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["wall", "damage"]

const BONUS_MULTIPLIER := 1.75

func activate() -> void:
	GameState.ball.wall_bounce_damage_bonus *= BONUS_MULTIPLIER
