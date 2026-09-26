class_name UpgradeLingeringPower
extends Upgrade

## Stays alive and reacts to every ult cast for the rest of the run. Each
## cast refreshes the window instead of stacking a second application —
## whichever wait finishes last (deadline still matches _expires_at) is the
## one that actually turns it back off.
const ID := "lingering_power"
const DISPLAY_NAME := "Lingering Power"
const DESCRIPTION := "For a few seconds after firing, all damage +80%."
const CATEGORY := GameState.UPGRADE_CATAGORY.ULTIMATE
const RARITY := GameState.UPGRADE_RARITY.COMMON
const TAGS : Array[String] = ["ultimate", "damage"]

const BONUS := 0.8 # +80%
const DURATION := 4.0 # seconds

var _active := false
var _expires_at := 0.0

func activate() -> void:
	GameState.ult_spent.connect(_on_ult_spent)

func _on_ult_spent() -> void:
	if not _active:
		_active = true
		GameState.damage_bonus += BONUS
	_expires_at = Time.get_ticks_msec() / 1000.0 + DURATION
	_wait_and_expire()

func _wait_and_expire() -> void:
	var deadline := _expires_at
	await get_tree().create_timer(DURATION).timeout
	if _active and deadline == _expires_at:
		_active = false
		GameState.damage_bonus -= BONUS
