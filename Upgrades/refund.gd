class_name UpgradeRefund
extends Upgrade

const ID := "refund"
const DISPLAY_NAME := "Refund"
const DESCRIPTION := "Half your meter returns after firing."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.RARE
const TAGS : Array[String] = ["ultimate"]

func activate() -> void:
	GameState.ult_charge_manager.refund_on_spend_fraction += 0.5
