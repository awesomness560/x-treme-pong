class_name UpgradeBlaze
extends Upgrade

const ID := "blaze"
const DISPLAY_NAME := "Blaze"
const DESCRIPTION := "Damage +90% while ignited."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["ignition", "damage"]

const BONUS := 0.9

func activate() -> void:
	# Extends the base game's own ignited multiplier directly, rather than a
	# separate bucket — this is exactly what that field already means.
	GameState.ball.ignite_damage_multiplier += BONUS
