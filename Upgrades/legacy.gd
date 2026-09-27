class_name UpgradeLegacy
extends Upgrade

## Stays alive and reacts to every round cleared. Reads the round-scoped
## bonuses right before they'd normally reset (boss_dead fires well before
## spawn_encounter's reset — there's a whole upgrade-pick screen in between)
## and folds a third of them into the permanent bonus for good.
const ID := "legacy"
const DISPLAY_NAME := "Legacy"
const DESCRIPTION := "When a round ends, keep a third of that round's stacking bonuses forever."
const CATEGORY := GameState.UPGRADE_CATAGORY.ENDURANCE
const RARITY := GameState.UPGRADE_RARITY.LEGENDARY
const TAGS : Array[String] = ["damage", "stack"]

const KEEP_FRACTION := 1.0 / 3.0

func activate() -> void:
	GameState.boss_dead.connect(_on_boss_dead)

func _on_boss_dead() -> void:
	var round_total := GameState.round_damage_bonus + GameState.round_ignited_damage_bonus
	GameState.damage_bonus += round_total * KEEP_FRACTION
