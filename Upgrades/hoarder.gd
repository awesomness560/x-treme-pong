class_name UpgradeHoarder
extends Upgrade

## Stays alive and reacts to every future upgrade pick, recomputing its own
## contribution (subtract old, add new) so it always reflects the current
## count exactly — same pattern as Scar Tissue.
const ID := "hoarder"
const DISPLAY_NAME := "Hoarder"
const DESCRIPTION := "Each upgrade you own adds +20% damage. Scales as you pick up more."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["damage"]

const BONUS_PER_UPGRADE := 0.2

var _current_bonus := 0.0

func activate() -> void:
	Upgrades.upgrade_taken.connect(_recompute)
	# Credit itself immediately — commit() adds to Upgrades.taken before
	# calling activate(), so it's already counted here.
	_recompute()

func _recompute(_script: Script = null) -> void:
	GameState.damage_bonus -= _current_bonus
	_current_bonus = BONUS_PER_UPGRADE * Upgrades.taken.size()
	GameState.damage_bonus += _current_bonus
