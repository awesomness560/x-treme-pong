class_name UpgradeChainReaction
extends Upgrade

const ID := "chain_reaction"
const DISPLAY_NAME := "Chain Reaction"
const DESCRIPTION := "Border hits while ignited re-ignite the ball on the rebound."
const CATEGORY := GameState.UPGRADE_CATAGORY.HEAT
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["ignition", "border"]

## Extra speed the reignite adds on top of the normal reset to start_speed —
## the ball still slows down like any other border hit, this is a kick on
## top of that, not instead of it.
const SPEED_BOOST := 120.0

func activate() -> void:
	GameState.ball.reignite_on_border = true
	GameState.ball.reignite_speed_boost += SPEED_BOOST
