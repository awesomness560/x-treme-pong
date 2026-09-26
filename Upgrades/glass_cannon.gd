class_name UpgradeGlassCannon
extends Upgrade

const ID := "glass_cannon"
const DISPLAY_NAME := "Glass Cannon"
const DESCRIPTION := "All damage +75%, max HP -1."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["risk", "damage", "health"]

func activate() -> void:
	GameState.damage_bonus += 0.75
	GameState.max_player_health -= 1
	# Current HP can't sit above the new, lower cap.
	GameState.player_health = mini(GameState.player_health, GameState.max_player_health)
