class_name UpgradeRelentless
extends Upgrade

## Stays alive and reacts to every round cleared for the rest of the run —
## permanent and ever-stacking, same shape as Ascendant.
const ID := "relentless"
const DISPLAY_NAME := "Relentless"
const DESCRIPTION := "Each round cleared adds +30% damage for the rest of the run."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["damage", "stack"]

const BONUS_PER_ROUND := 0.3

func activate() -> void:
	GameState.boss_dead.connect(_on_boss_dead)

func _on_boss_dead() -> void:
	GameState.damage_bonus += BONUS_PER_ROUND
