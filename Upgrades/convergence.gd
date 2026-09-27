class_name UpgradeConvergence
extends Upgrade

const ID := "convergence"
const DISPLAY_NAME := "Convergence"
const DESCRIPTION := "A perfect smash on an ignited ball deals +800% damage."
const CATEGORY := GameState.UPGRADE_CATAGORY.STRIKE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["perfect", "ignition", "damage"]

const BONUS := 8.0

func activate() -> void:
	GameState.ball.convergence_damage_bonus += BONUS
