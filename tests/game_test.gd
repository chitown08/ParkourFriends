class_name GameTest
extends Node
## Base class for automated gameplay tests.
##
## Each test file extends this and adds functions whose names start with
## "test_". Before each one, a fresh copy of the game is started; the test
## then "presses" buttons in code and checks what happened with expect().

const MAIN_SCENE := preload("res://game/main.tscn")
## The move tests are built around realistic numbers on the test course.
const HUMAN := preload("res://player/profiles/human.tres")
const SUPERHUMAN := preload("res://player/profiles/superhuman.tres")
const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"jump", &"crouch", &"respawn", &"free_run",
]

## Camera angles: which way "forward" points.
const FACE_NORTH := 0.0 ## Toward -Z (the main course).
const FACE_WEST := PI / 2 ## Toward -X (the Ledge Yard).

var main: Node
var player: Player
var failures: Array[String] = []


func before_each() -> void:
	main = MAIN_SCENE.instantiate()
	add_child(main)
	main.start_solo("test_course") # The tests' positions are all on the test course.
	await ticks(5)
	player = main.get_node_or_null("Players/1")
	expect(player != null, "the game should have created a player")
	if player:
		player.set_profile(HUMAN)


func after_each() -> void:
	release_all()
	main.queue_free()
	await ticks(2)


# --- Controls ----------------------------------------------------------------

func ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)


## Hold a button for some physics ticks (60 ticks = 1 second).
func hold(action: StringName, tick_count: int) -> void:
	Input.action_press(action)
	await ticks(tick_count)
	Input.action_release(action)


## Quick press and release.
func tap(action: StringName) -> void:
	await hold(action, 3)


## Sends a one-off button press through the game's normal input handling
## (for things handled as input events, like the pause menu).
func press_event(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(3)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await ticks(3)


## Teleports the player, standing still, with the camera facing `yaw`.
func place(feet: Vector3, yaw: float) -> void:
	release_all()
	player.global_position = feet
	player.velocity = Vector3.ZERO
	player.change_state(&"Air")
	player.reset_physics_interpolation()
	player.camera_rig.yaw = yaw
	await ticks(30)


## Runs forward and jumps once the player passes `jump_at` along the running
## direction. Stops holding forward as soon as the player grabs a ledge,
## climbs, or lands somewhere higher than they started.
func run_and_jump(jump_at: float, axis := Vector3.FORWARD, max_ticks := 120) -> void:
	var start_y := player.global_position.y
	var jumped := false
	Input.action_press(&"move_forward")
	for i in max_ticks:
		await ticks(1)
		if not jumped and player.global_position.dot(axis) > jump_at:
			Input.action_press(&"jump")
			jumped = true
		if player.state.name in [&"Hang", &"Climb"]:
			break
		if jumped and player.state.name == &"Ground" and player.global_position.y > start_y + 0.3:
			break
	release_all()


# --- Climbing (a little robot that climbs the way a player would) ---

## Jumps toward `direction`, grabs/vaults whatever is there and climbs up.
## Returns true if the player ends up standing at about `expected_height`.
func jump_and_climb(direction: Vector3, expected_height: float) -> bool:
	release_all()
	player.camera_rig.yaw = yaw_for(direction)
	await ticks(2)
	Input.action_press(&"move_forward")
	Input.action_press(&"jump")
	for i in 90:
		await ticks(1)
		if player.state.name in [&"Hang", &"Climb"]:
			break
		if i > 5 and player.state.name == &"Ground" and player.global_position.y >= expected_height - 0.1:
			break # Jumped straight up onto it, no grab needed.
	release_all()
	if player.state.name == &"Hang":
		await tap(&"jump")
	return await wait_until_on_top(expected_height - 0.1, 60)


func wait_until_on_top(min_height: float, max_ticks: int) -> bool:
	for i in max_ticks:
		await ticks(1)
		if player.state.name == &"Ground" and player.global_position.y >= min_height:
			await ticks(3)
			return true
	return false


func yaw_for(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


# --- Checks ------------------------------------------------------------------

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func expect_near(actual: float, expected: float, tolerance: float, what: String) -> void:
	expect(absf(actual - expected) <= tolerance,
			"%s: expected %.2f (±%.2f), got %.2f" % [what, expected, tolerance, actual])


func expect_state(expected: StringName) -> void:
	expect(player.state.name == expected,
			"expected state %s, got %s" % [expected, player.state.name])
