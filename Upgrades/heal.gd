class_name UpgradeHeal
extends Upgrade

## Not in the catalog: the UI spawns this directly whenever HP is below max,
## instead of rolling it from the pool.
const ID := "heal"
const DISPLAY_NAME := "Second Wind"
const DESCRIPTION := "Restore 1 HP."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAL
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["health"]

func activate() -> void:
	GameState.player_health = mini(GameState.player_health + 1, GameState.max_player_health)
