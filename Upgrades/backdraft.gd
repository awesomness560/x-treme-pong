class_name UpgradeBackdraft
extends Upgrade

const ID := "backdraft"
const DISPLAY_NAME := "Backdraft"
const DESCRIPTION := "Wall bounces while ignited damage the border a little."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["wall", "ignition", "border", "damage"]

const DAMAGE_PER_BOUNCE := 15.0

func activate() -> void:
	GameState.ball.wall_ignite_damage += DAMAGE_PER_BOUNCE
