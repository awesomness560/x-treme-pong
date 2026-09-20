extends Node

## Base rarity odds. Rarity is rolled first and never changes once picked.
const RARITY_WEIGHTS := {
	GameState.UPGRADE_RARITY.COMMON: 0.60,
	GameState.UPGRADE_RARITY.RARE: 0.33,
	GameState.UPGRADE_RARITY.LEGENDARY: 0.07,
}

## Extra category weight per upgrade already owned in that category.
const CATEGORY_OWNED_BONUS := 0.5

## Every upgrade that can be rolled. Heal is deliberately not here — the UI
## spawns it directly instead of drawing it from the pool.
const CATALOG : Array[Script] = [
	preload("res://Upgrades/low_flashpoint.gd"),
	preload("res://Upgrades/heavy_hand.gd"),
	preload("res://Upgrades/higher_ceiling.gd"),
	preload("res://Upgrades/kindle.gd"),
	preload("res://Upgrades/unstable_combo.gd"),
]

const HEAL_SCRIPT : Script = preload("res://Upgrades/heal.gd")

var _pool : Array[Script] = []
var _category_counts : Dictionary = {}

func _ready() -> void:
	_pool = CATALOG.duplicate()

## Rolls up to `count` distinct upgrades from the remaining pool. Upgrades
## offered but not picked aren't removed here — only commit() does that.
func roll(count: int) -> Array[Script]:
	var picks : Array[Script] = []
	var available := _pool.duplicate()

	for i in count:
		if available.is_empty():
			break
		var script := _pick_any(available)
		if script == null:
			break
		picks.append(script)
		available.erase(script)

	return picks

## Rolls a rarity, falling back to a different one if that tier is completely
## empty, so a roll only comes up short when the whole pool is exhausted.
func _pick_any(available: Array[Script]) -> Script:
	var rarities := RARITY_WEIGHTS.duplicate()
	while not rarities.is_empty():
		var rarity = _weighted_pick(rarities)
		var script := _pick_for_rarity(available, rarity)
		if script != null:
			return script
		rarities.erase(rarity)
	return null

## Instantiates and activates the chosen upgrade, then removes it from the
## pool for good. Heal isn't in the pool, so erase() there is just a no-op.
func commit(script: Script) -> Upgrade:
	_pool.erase(script)
	var category : GameState.UPGRADE_CATAGORY = script.CATEGORY
	_category_counts[category] = _category_counts.get(category, 0) + 1

	var instance := script.new() as Upgrade
	add_child(instance)
	instance.activate()
	return instance

## Category rules over nothing; rarity rules over category. If the weighted
## category pick has nothing available, drop it and reroll among the rest.
func _pick_for_rarity(available: Array[Script], rarity: GameState.UPGRADE_RARITY) -> Script:
	var weights := _category_weights(available, rarity)
	while not weights.is_empty():
		var category = _weighted_pick(weights)
		var matches := available.filter(func(s): return s.RARITY == rarity and s.CATEGORY == category)
		if not matches.is_empty():
			return matches[randi() % matches.size()]
		weights.erase(category)
	return null

## Each category present at this rarity starts at weight 1, plus a bonus per
## upgrade already owned in that category — owning more begets more.
func _category_weights(available: Array[Script], rarity: GameState.UPGRADE_RARITY) -> Dictionary:
	var weights := {}
	for script in available:
		if script.RARITY != rarity:
			continue
		var category = script.CATEGORY
		if not weights.has(category):
			weights[category] = 1.0 + CATEGORY_OWNED_BONUS * _category_counts.get(category, 0)
	return weights

func _weighted_pick(weights: Dictionary):
	var total := 0.0
	for weight in weights.values():
		total += weight
	var roll := randf() * total
	var accumulated := 0.0
	for key in weights:
		accumulated += weights[key]
		if roll <= accumulated:
			return key
	return weights.keys()[0]
