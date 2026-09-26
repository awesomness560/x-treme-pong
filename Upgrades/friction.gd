class_name UpgradeFriction
extends Upgrade

const ID := "friction"
const DISPLAY_NAME := "Friction"
const DESCRIPTION := "Ball damage rises the longer the rally goes, resetting on a border hit."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["speed", "damage", "tap"]

## +5% damage per second the current rally has lasted.
const RATE_PER_SECOND := 0.1
## Caps the bonus so an unusually long rally can't run away with it.
const MAX_BONUS := 1.0 # +100%

func activate() -> void:
	GameState.ball.rally_damage_rate += RATE_PER_SECOND
	GameState.ball.rally_damage_bonus_cap = MAX_BONUS
