class_name MovementProfile
extends Resource
## A complete set of movement numbers: how fast you run, how high you jump,
## how wall runs and tosses feel... Swap profiles to change the whole feel.
##
## The profiles live in player/profiles/ (superhuman.tres is the default,
## human.tres has realistic numbers). Double-click one in Godot's FileSystem
## panel to tweak it in the Inspector. The defaults below are the superhuman ones.

@export_group("Running")
@export var run_speed := 10.0 ## Normal running speed.
@export var flow_speed := 15.0 ## Top speed, reached by keeping your flow (momentum) going.
@export var flow_build_time := 3.0 ## Seconds of uninterrupted running to reach top speed.
@export var flow_decay_time := 0.6 ## Seconds to lose all flow once you stop or crash.
@export var ground_acceleration := 80.0
@export var ground_friction := 60.0 ## How fast you stop when you let go.
@export var air_acceleration := 25.0 ## How much you can steer mid-air.
@export var air_friction := 2.0 ## Keeps your momentum when you let go mid-air.
@export var turn_speed := 14.0 ## How fast the body turns to face where you run.

@export_group("Jumping")
@export var jump_height := 3.0 ## Meters, if you hold the jump button.
@export var jump_time_to_peak := 0.42 ## Seconds to reach the top of a jump.
@export var jump_time_to_fall := 0.34 ## Seconds to fall back down (snappier than going up).
@export_range(0.0, 1.0) var jump_cut := 0.5 ## Releasing jump early keeps this much upward speed.
@export var coyote_time := 0.12 ## You can still jump this long after running off a ledge.
@export var jump_buffer_time := 0.12 ## Pressing jump this early before landing still counts.
@export var max_fall_speed := 55.0

@export_group("Ledges")
@export var ledge_max_height := 2.6 ## Highest ledge (above your feet) you can grab.
@export var hang_min_height := 1.2 ## Ledges lower than this are vaulted over instead of hung from.
@export var mantle_min_height := 0.15 ## Ledges lower than this are just stepped onto.
@export var ledge_detect_distance := 0.4 ## How far in front of your body to look for walls.
@export var ledge_grab_max_rise_speed := 1.5 ## Can't grab while still rising faster than this.
@export var hang_height := 1.7 ## How far your feet hang below the ledge.
@export var hang_snap_speed := 10.0 ## How fast you slide into the hanging spot.
@export var shimmy_speed := 3.0
@export var climb_up_time := 0.35 ## Seconds to pull up from hanging.
@export var mantle_time := 0.2 ## Seconds to vault over a low ledge.
@export var ledge_regrab_delay := 0.35 ## After letting go, can't re-grab for this long.
@export var ledge_leap_height := 4.5 ## While hanging, jump to leap to a ledge up to this far above.
@export var ledge_leap_speed := 14.0 ## How fast a ledge leap carries you up (m/s).

@export_group("Crouching & Sliding")
@export var crouch_speed := 4.0
@export var slide_min_start_speed := 7.0 ## Need to be moving at least this fast to slide (otherwise you just crouch).
@export var slide_boost := 1.5 ## Extra speed when a slide starts (only up to top speed + this).
@export var slide_friction := 4.0 ## How fast a slide slows down on flat ground (m/s per second).
@export var slide_slope_gravity := 45.0 ## How strongly slopes speed you up (or slow you down) while sliding.
@export var slide_steer_speed := 1.5 ## How fast you can turn while sliding (radians per second).
@export var slide_max_speed := 22.0
@export var slide_end_speed := 4.0 ## The slide ends (you're just crouching) below this speed.

@export_group("Walls")
@export var wall_detect_distance := 0.6 ## How far beyond your body a wall counts as "next to you".
@export var wall_jump_push := 9.0 ## How hard a wall jump pushes you away from the wall.
@export var wall_jump_height := 2.5 ## How high a wall jump goes (meters).
@export var wall_jump_control_lock := 0.25 ## After a wall jump, steering is ignored this long so you clear the wall.
@export var wall_run_min_speed := 7.0 ## Need to be moving along the wall at least this fast.
@export var wall_run_speed := 11.0 ## Minimum speed while wall running.
@export var wall_run_lift := 3.0 ## Upward speed when a wall run starts.
@export var wall_run_gravity := 5.0 ## Much weaker than normal, so you stay up for a while.
@export var wall_run_max_time := 1.6 ## Seconds before you peel off the wall.
@export var wall_run_min_height := 1.0 ## Must be at least this high off the ground to start.
@export var wall_run_lean_degrees := 20.0 ## How far the body leans away from the wall.
@export var wall_scramble_speed := 7.0 ## Running straight up a too-tall wall: how fast (m/s)...
@export var wall_scramble_time := 0.5 ## ...and for how long (seconds). 7 x 0.5 = 3.5 m.

@export_group("Ziplines")
@export var zipline_gravity := 25.0 ## How quickly you speed up going down (scaled by how steep the cable is).
@export var zipline_min_speed := 4.0 ## Slowest you ride (e.g. after grabbing it from a standstill).
@export var zipline_max_speed := 26.0
@export var zipline_grab_radius := 0.9 ## How close your hands must get to a cable to grab it.
@export var zipline_hang_height := 2.0 ## How far your feet hang below the cable.
@export var zipline_regrab_delay := 0.4 ## After leaving a zipline, can't grab one again for this long.

@export_group("Tossing")
@export var toss_range := 2.0 ## How close a friend must be to toss them (meters, not behind you).
@export var toss_height := 8.0 ## How high a toss launches a friend.
@export var toss_forward_speed := 8.0 ## How fast a toss sends them the way your camera faces.
@export var toss_recoil_height := 1.8 ## Tossing someone while you're in the air gives you a hop this high.
@export var toss_control_lock := 0.3 ## A tossed player can't steer for this long.
@export var toss_cooldown := 0.4 ## Seconds between tosses.
## On: once in the air you can be tossed only once, and toss only once, until
## you land, grab a ledge, or touch a wall. Off: unlimited juggling.
@export var limit_tosses_per_air := true
