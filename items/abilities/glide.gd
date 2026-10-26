extends ItemAbility
## The glider: hold "use item" (right mouse / left trigger) in the air to glide.
## Loses height steadily and turns poorly (see player/states/glide.gd).

const SPEED := 16.0 ## Cruising speed (m/s); faster entries ease down to it.
const SINK_SPEED := 3.0 ## Height lost per second (m/s): about 5 m forward per metre down.
const TURN_RATE := deg_to_rad(50.0) ## Per second: wide, lazy turns.


func physics_update(player: Player, _delta: float) -> void:
	if player.state.name == &"Air" and player.input.use_item_held:
		player.change_state(&"Glide", {"item": item, "speed": SPEED, "sink_speed": SINK_SPEED, "turn_rate": TURN_RATE})
