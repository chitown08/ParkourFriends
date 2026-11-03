extends ReachRule
## Launchers (levels/launcher.gd): run up one at full flow and it throws you up
## from its launch point; at the top you can grab (or scramble onto) a place
## beside you, and touch relics. A wall ramp, so, gets you onto the roof it's
## built along; a quarter-pipe under a wall, up it.

## How far across (from the top of the launch) a place can be and still be grabbed.
const REACH := 2.5


func add_links(map: ReachMap) -> void:
	var m := map.moves
	var flow: Array[StringName] = [&"flow"]
	for launcher: Launcher in map.level.find_children("*", "Launcher", true, false):
		var foot := map.place_under(launcher.global_position + Vector3.UP * 0.5)
		if foot == null:
			continue
		var at := launcher.launch_point()
		var launch := launcher.global_position - launcher.global_basis.z * at.x
		var top := launch.y + at.y + launcher.rise_for(m.flow_speed) + Launcher.LEAP_BONUS
		var spot := ReachMap.Spot.new()
		spot.area = Rect2(launch.x, launch.z, 0.0, 0.0)
		for to in map.places:
			if to == foot or to.y <= foot.y or ReachMap.gap(spot, to) > REACH:
				continue
			# Grab its edge on the way up, or scramble up its wall from the top.
			if to.y <= top + m.ledge_max_height:
				map.add_link(foot, to, "launcher", flow)
		spot.y = top
		for target in map.targets:
			if touches(spot, target, 0.0):
				map.add_link(foot, target, "launcher", flow)
