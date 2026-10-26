extends ItemAbility
## Placeholder ability for the Test Balloon: while it's in your hands you fall
## slowly. Mainly here to prove the ability system works.

const MAX_FALL_SPEED := 4.0


func physics_update(player: Player, _delta: float) -> void:
	if player.state.name == &"Air" and player.velocity.y < -MAX_FALL_SPEED:
		player.velocity.y = -MAX_FALL_SPEED
