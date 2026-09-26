extends Label

var round : int = 1

func _ready():
	text = "Round: " + str(round)
	GameState.next_round.connect(_on_next_round)

func _on_next_round():
	round += 1
	text = str("Round: " + str(round) )
