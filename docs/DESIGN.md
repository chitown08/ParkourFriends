# Parkour Friends: technical design notes

**The master design document is the Claude doc
["Parkour Friendslop – Game Design Doc"](https://claude.ai/artifact/FaCnq4frncwnN9L2MgsfSU).**
It holds the vision, world, items, puzzles, progression, multiplayer and roadmap. Where this
file and the Claude doc disagree, the Claude doc wins. This file only records how things are
built and the details the code relies on.

## Decisions reflected in the code (Oct 2026)

| Decision | What it means in the code |
|---|---|
| One big city | The floating-islands prototype (Old Town) was removed; the Rooftop District is the default world for now |
| Free-run stays | `player/free_run.gd`, switchable in the pause menu |
| Throw chains are rewarded | You can toss once per air time, and each friend can toss you once per air time (`tossed_by` in `player.gd`) |
| Base moves never change | No agility levels; relics are collectibles you carry back to a drop-off |
| Puzzles, not the clock | No timers or time trials |

## How movement is built

- **States** (`player/states/`): one script per mode: Ground, Air, Hang, Climb, Crouch, Slide,
  WallRun, WallScramble, Grind (riding a grind rail), PipeClimb (climbing a drainpipe), Vault (the flow vault), ChainHang and ChainClimb (the hanging chain), Brace and LegUp (the leg-up), Linked, Whip and Whipped (crack the whip), Catch and Caught (catching a friend). Only the active state runs; it decides how to move and when
  to switch (`player.change_state()`).
- **Movement profiles** (`player/profiles/`): every feel number lives in a profile.
  `superhuman.tres` is the default; `human.tres` keeps realistic numbers and is what the
  move tests on the test course use.
- **Free-run** is a co-pilot that presses buttons on `PlayerInput` (jump, crouch); every
  automatic move is a normal move a player could do by hand. The exception is the **flow vault**
  (`player/states/vault.gd`): head-on at something up to 1.3 m high and 2 m deep (benches, bins,
  red air-con boxes), free-run skims over it, feet 0.15 m clear of the top, at the speed you hit
  it, then drops you down the far side still running. Anything taller or deeper is jumped as
  before; a readied leap still leaps. Numbers: the "Flow vault" group in the movement profile.
  It plays the `vault` animation for now; a lower, quicker one would suit it better.
- **Free-run at too-tall walls**: head-on at speed (over half run speed), free-run jumps anyway and
  you scramble up, grabbing any ledge or window sill that comes into reach (steer onto one as you come
  in). Nothing to grab: you slide back down and stop, and it doesn't try again without a run-up.
- **Free-run leap**: in free-run your jump button readies a leap while held (0.3 s for a full
  one) and takes off when you let go, or at the next edge or obstacle free-run would jump. A full
  leap is 4.5 m high (a jump is 3) and adds 3 m/s forward: enough to clear the 10 m gap without
  full flow. A tap (under 0.1 s) is a normal jump. Numbers: the "Leap" group in the movement profile.
- **Pack-running**: friends free-running within 8 m (and 3 m up or down), heading within 45° of where
  you steer, are your pack. Your heading bends a little toward theirs and toward them sideways, and your
  top speed eases up to 20% faster or slower to keep alongside (their speed, plus a bit to close a gap).
  No leader: everyone does the same. It never jumps for you, and steering away or letting go of
  free-run breaks it. The HUD shows "pack of N". Solo, H makes the practice buddy a **ghost runner**
  that free-runs with you (wandering 15° either side of your heading; it reappears beside you if it
  falls 20 m behind). Numbers: the PACK_ constants in `player/free_run.gd`.
- **Drafting** (co-op): running in a pack, flow builds faster (half again as fast for each friend:
  a pack of four reaches top speed in 40% of the time) and top speed goes up 3% for each friend (up
  to 9% in a pack of four), for everyone in it. So a bigger pack can clear a gap nobody can alone,
  all together. Numbers: `DRAFT_SPEED`, `DRAFT_FLOW`, `MOST_DRAFTING` in `player/player.gd`.
- **Flow** builds while you keep moving at speed and drains only on the ground (stopping,
  letting go, crashing). Vaults come out at flow speed.
- **The character** is a Meshy model rigged and animated in Mixamo (`characters/blob/`, see
  `docs/CHARACTER_GUIDE.md`). Godot pulls each animation out of its FBX on import (scaled to 1.8 m,
  looping set per move); `CharacterModel` picks one from your state and speed each frame (puppets
  too, from what the network sends), strips any travel Mixamo baked in, and plays one-off moves
  (swing, throw, toss, hard landing). Sounds are still stand-ins.
- **Cosmetics** (`player/cosmetics.gd`, `docs/COSMETICS_GUIDE.md`): GLBs in `cosmetics/<slot>/`, each fitted
  onto the blob at rest by an entry in `cosmetics/fits.cfg` (check with `tools/cosmetics_lineup.gd`,
  which renders every outfit; `tools/inspect_cosmetics.gd` and `tools/cosmetics_sheet.gd` help
  fit a new one) and hung from a bone with a BoneAttachment3D, so it follows the animations. Pairs
  are fitted on the left and mirrored for the right. `Player.sync_outfit` (sent to everyone) says
  what you wear: picked per slot in the pause menu ("Your outfit", "None" to start), saved in
  `Settings.outfit` and put on when you join (`Cosmetics.tidy()` drops anything no longer made); O
  still cycles whole outfits for developers. In an exported game only `*.glb.import` files are
  listed in a folder, so `Cosmetics.available()` reads those too. When exporting, add `*.cfg` to the
  export filter so the fits file goes along.
- **Trails** (`player/trail.gd`): a banner or streamer flies from a pole on your back, a scarf's
  two tails from the back of your neck. The straight model is skinned onto a 10-link chain built
  at runtime; the chain lags behind you (Verlet), sags, catches a breeze out behind, ripples more
  the faster you go, and stays out of a capsule round your body. Links keep their length with
  "dynamic follow the leader" (Müller), so the free end doesn't curl. It steps with physics and
  is drawn between steps like the body (physics interpolation), and each screen runs its own.
  Per-kind feel is `Trail.KINDS`; `tools/trail_preview.gd` renders each trail standing and running.
  On top, `Player._pose_visual()` squashes, stretches and tilts the whole model: squashed while
  readying a leap, stretched by a jump, squashed by a landing, tipped forward and banking while
  gliding; the bat sweeps round in an arc (`item_anchor()`), and whoever it hits flashes white.
  Background music: a world with music starts with its own song (`Level.music`, set by the level
  generators), then plays every track in `audio/music/` shuffled (`game/playlist.gd`: each once a
  round, never the same twice running); add music by copying files there. **Layered songs** (`game/layered_song.gd`): a folder made by
  `tools/mix_song.sh` from Suno stems plays all its layers in step (an `AudioStreamSynchronized`), each
  faded (1.5 s) by how many friends are pack-running with you: base always, pack1 with one, pack2 with
  two, all the `extra-*` with three (otherwise one or two, picked as the song starts). Alone, a
  low-pass filter on the Music channel muffles it a little (3.5 kHz), opening as a friend joins. The
  district starts with its layered song (`Level.music_folder`). M mutes it and the pause menu has a volume slider (both saved in Settings).
  Sounds are made from code (`game/sfx.gd`) and bursts of bits (dust, the bat's "pop") by
  `game/effects.gd`. One-off effects reach everyone through `Player.show_effect()`.

- **Hanging chain** (co-op): crouch-walk off an edge to hang from it. A friend who jumps or scrambles
  up to a hanging player's feet (hands within 0.8 m) hangs from them, one per pair of feet, and so on
  down: each adds about 1.7 m of reach, so a scramble reaches a 10 m top with one friend hanging and
  11.5 m with two (alone it's about 9). Jump to climb the chain (8 m/s) onto the top; when the one above
  pulls up or climbs past, you move up into their place; if they let go, you drop. Each player sends
  `sync_hanging_on` (who they hang from) and hangs from where they see their friend, so it works
  online. Free-run climbs a chain for you. Solo, G while hanging makes the buddy hang there too.
- **Leg-up** (co-op): with nobody in toss reach, the toss button (E) braces you at the wall you're next to:
  back to it, hands cupped (Brace). Press it again beside a braced friend and you climb onto their
  shoulders and brace there instead (up to 4 in a stack, each 1.5 m higher). Anyone who jumps beside the
  bottom one, or jumps into them, heading for the wall, steps up the stack (LegUp) and is launched
  `leg_up_height` (5 m) up from the top hands, straight into a scramble: about 11.6 m of wall with one
  friend braced, 13.1 m with two, 14.6 m with three. Those bracing stay below; once someone is up, a
  hanging chain can bring them up after. Each player sends `sync_braced_on` (whose shoulders they're on);
  the runner's computer decides from what it sees, so it works online. Free-run takes a leg-up for
  you. Solo, G while looking at a wall (within 10 m) has the buddy brace at its foot.
- **Crack the whip** (co-op): free-running in a pack, the toss button (E) takes the nearest friend's
  hand instead of tossing them: you join the end of their line (Linked), running in a row across the
  way the leader (the one at the other end) goes, 1.2 m apart, up to 6 in a line. You're carried
  along (and jump when the leader jumps); E, jump or crouch lets go, and so does being dragged 3 m
  from your spot. The leader cracks the whip by steering hard (60°+) their own way, away from the
  line, while running: they plant and pivot (Whip), the line swings a quarter turn round them
  (Whipped, 0.4 s), and each is let go going 30% faster than they ran for each place out from the
  leader; the one on the end is flung into the air as high as a full leap. A line of two flings
  someone further than anyone can leap alone; at full flow, ~18 / 22 / 26 m across for lines of
  2 / 3 / 4. Each player sends `sync_linked_to` (whose hand they hold); each computer moves its own
  player from what it sees, so it works online. Solo, E while ghost-running has the buddy take
  your hand (more practice bots join the end). Numbers: `LINK_`/`WHIP_` constants in `player.gd`.
- **Catch** (co-op): stand at an edge looking out over it, and a friend falling short of it is
  caught: nothing to press. If their hands come within 1.5 m out from the wall and 2 m below the
  edge (and they're not heading away: dropping off on purpose), you kneel and hold them (Catch)
  and they hang from your hands right at the edge (Caught), as if they'd grabbed it themselves: jump
  climbs up (free-run does it for you), crouch lets go. More friends can hang below them like any
  hanging chain, and when the caught one climbs up, the next takes their place. You can stand up
  to 1.5 m back; you stay put while holding on; jump or crouch lets go (they drop). One catch at a
  time. The falling player's computer decides from where it sees you (`Player.find_catcher()`) and
  sends `sync_hanging_on`; yours sees it and kneels, so it works online. Solo, G at an edge looking
  out has the buddy stand there beside you, to catch you. Numbers: `CATCH_` constants in `player.gd`.
- **Grind rails** (`levels/grind_rail.gd`) are straight (`end_point`) or any shape (a `curve`, a Curve3D:
  bends, coaster dips and rises, flat wires). Places on a rail are metres from its start. The Grind state
  works in those: the slope where you are pulls you downhill (`grind_gravity`), pushing along the rail
  works you up to `grind_climb_speed` that way (up a slope or along a flat), and either end flings you
  off along it. You're placed on the rail each tick, so a moving rail (a trolley, a coaster car's track)
  carries you. Landing anywhere along one (not right at an end) grabs it. Ideas this opens up: roller
  coaster tracks, trolley lines, sign edges, wires between buildings.

| Rule the levels depend on (superhuman profile) | Value |
|---|---|
| Running (no Shift) / free-running / top speed with full flow | 7 / 10 / 15 m/s (flow only builds while free-running, and drains when you let go of Shift) |
| Full jump | ~3 m |
| Highest ledge you can grab from a jump | ~5.6 m |
| Wall scramble | ~3.5 m up, once per wall until you land |
| Highest wall you can get up alone (scramble, then grab) | ~8.7 m from a jump, ~10.2 m from a readied leap |
| Ledge leap (from a hang-only sill) | up to 4.5 m |
| Toss | ~8 m up, ~8 m/s in the camera's direction |
| Leg-up (one friend braced / two / three) | ~11.6 / 13.1 / 14.6 m of wall |
| Crack the whip, at full flow (line of 2 / 3 / 4) | flung ~18 / 22 / 26 m across |
| Catch (a friend at the edge) | your hands within 1.5 m out, 2 m below the edge: ~1 m lower and ~2 m further than grabbing it yourself |
| Grind rail top speed (sliding down) / climbing up | 26 / 5 m/s |

## Controls (Nov 2026)

**Rally call** (Q / LB, `Player.show_rally()`): a whistle, and for 6 s a beam of light in your colour
rises from you (drawn through buildings); friends' HUDs show your name and distance over you, or an
arrow at the screen's edge pointing the way to turn (`hud.gd rally_marker_place()`). 2 s between
calls. Plays a `wave` animation if there is one.

**Camera** (`player/camera_rig.gd`): 3.75 m behind you, easing back 1 m for each friend pack-running
with you (up to three), so you see the crowd.

Kept to a handful of buttons, each doing whatever fits where you are: E is everything with a
friend (toss, brace, shoulders, take a hand), F everything with items (tap: pick up / drop / hand
over; hold 0.3 s: throw, `PlayerInput.THROW_HOLD`), C crouches, slides and lets go. Many moves have
no button at all (catch, crack the whip, ledge grabs, wall moves, drainpipes). Free-run stays a
held button, so you only join a pack when you mean to. On screen: a short card in a corner (F1
hides it) and one prompt for what a button would do right now, from `Player.control_hints()` (moves)
and `ItemCarrier.control_hints()` (items, with each ability's `use_hint()`); both name the keyboard
or gamepad control, whichever was used last (`ui/control_names.gd`). Developer tools (practice
buddy G / J / H, outfits O, readout F3) only work when `Settings.dev_tools` is on: running from the
editor or a debug build, not the build friends play.

## You, your settings, the version (Nov 2026)

- **Name**: typed in the start menu (`Settings.player_name`, up to 16 characters; "Player" if
  none), sent to everyone as `Player.sync_player_name` and shown over your head on friends' screens
  (a Label3D: the same size at any distance, seen through walls, in your body colour, lightened).
  Not over your own head. Maybe trails will do this job one day.
- **Settings** (`game/settings.gd`, saved in the user data folder): mouse, invert, fullscreen (F11),
  volume for everything (the Master channel), music (its player) and sound effects (an Effects
  channel all `Sfx` sounds go through), plus developer-only movement feel and free-run switch. The
  tests use their own settings file (`user://test_settings.cfg`), never yours.
- **Version**: Project Settings > Application > Config > Version (`0.1.0`), shown as "v0.1.0 alpha"
  in a corner of the start menu, the pause menu and the game screen, so bug reports say which.

## Multiplayer

- Host and join (ENet, port 7777, up to 4 players). Each player's computer runs their own
  character and shares position, facing, state, lean, how readied a leap is, and who has tossed
  them. Jumps and bat swings are announced as they happen, for the sounds and effects.
- The host owns world state (relics delivered) and picks the world; joiners receive it.
- The host owns every item: it runs their physics and decides who holds what, so two players
  grabbing at once can't both get it. Players' computers only ask (`request_pick_up`,
  `request_drop`, `request_throw`).

## Items (groundwork)

- Items are real physics objects (`WorldItem`, a RigidBody3D). Each kind is an `ItemData`
  resource plus an optional `ItemAbility` script, so new items need no changes to shared code.
- One thing at a time, in your **hands** (the item's ability runs there): if you aren't holding
  it, you aren't using it. F picks up, drops or hands over; held, it throws. (The backpack and
  its second slot were dropped in Nov 2026: it got in the way of trails, and wasn't worth a button.)
- **Bulky** items (the crate now, the glider later) need both hands: no ledge grabs, climbs,
  vaults or scrambles while one is in your hands, and you let go if one lands in your hands
  mid-climb. Drop it to climb. Wall runs, wall jumps and grind rails still work
  (you grind a rail on your feet, like a skateboarder, so your hands stay free).
- **Relics** are items: they hover at home until touched (touching picks them up if your hands
  are free), and only count once carried or thrown into a drop-off (`levels/drop_off.tscn`,
  beside the Free-Run Line's spawn, and in the middle of the district's plaza). A relic you drop or throw needs F to pick up again.
- Throwing: items fly where the camera points. A thrown item passing within 1.3 m of a friend's
  chest is caught if they have a free slot (you can't catch your own for 0.4 s). Dropped items
  can't be caught. F while facing a friend within 2 m hands the item over.
- Items go home after falling below the kill height, after 90 s lying away from home, or
  when the player holding them leaves the game.
- **Glider** (the first real tool): hold "use item" in the air to glide. Cruises at 16 m/s,
  sinks 3 m/s (about 5 m forward per metre down), turns at 50°/s. Bulky, so it's held overhead
  and blocks climbing. One sits on the leap tower roof, with an island east of it that only a
  glide reaches (it has a relic). Numbers live in `items/abilities/glide.gd`.
- **Baseball bat**: "use item" swings (0.6 s apart). Hits the friend in front of you (2.5 m
  reach) at 40 m/s, 40° up, the way your camera faces: over 30 m on flat ground. It counts as
  a throw-chain link (`launch_friend` in `player.gd`, shared with tosses). With no friend in
  reach it hits the item in front instead (25 m/s, 30° up), which flies like a throw, so a
  friend can catch it, and knocks hovering relics loose. Numbers: `items/abilities/bat_swing.gd`.
- Placeholders: **Crate** (bulky, no ability), **Test Balloon** (slows your fall while in your
  hands), at the start of the Free-Run Line.
- Item list (Oct 2026, see the master doc): glider, grappling hook, baseball bat (send a friend
  a long way), pogo stick (clumsy). Dropped: backpack, parachute, running shoes, roller skates,
  suction-cup hands (for now). Tools are always used by hand: free-run never uses them.

## Group runs (`levels/group_run.gd`, `run_gate.gd`, Nov 2026)

Never a race: no clock, and the route waits for the crew. A run's start is a glowing ring with a
sign (name, "Relics: 2 of 4", who it's waiting for); with the whole crew (everyone in the game, not
the practice buddy) in the ring, a 3 s countdown and it's on. Only then do the gates show. White
gates are the route: each of you goes through the lit one (it becomes your checkpoint), and the next
only lights once the whole crew is through ("Waiting for Bo" over it). Gold gates are extras put
somewhere hard: one of you through is enough. When the crew is all through the last white gate, the
run's relics appear there (locked `WorldItem`s, `locked = true`, until then): one for finishing the
first time, and one for each gold gate got this run that hadn't been before. Only finishing pays; finishing also sets off a party over the last gate for everyone (`celebrate()`: fireworks, lots if you got a gold gate) with "Run complete!" on screen;
runs can be done again. Someone joining or leaving mid-run ends it (start again together). The host
decides; each computer reports its own player going through gates. The reachability checker treats
gates as targets: white gates must take one player, gold gates more (`tests/test_group_run.gd`). The
district has one so far, "Warm-up" (`gen_district.gd _write_runs()`): ring on the free roof nearest
the spawn, five white gates hopping roof to roof, two gold gates floating 9.5 m up (a toss).
Ideas for later: follow the leader, night runs, reversed routes.

**The hub tower's relic board** (`levels/relic_board.gd`): the tower nearest the plaza carries, near
the top of the face looking toward the plaza, a 2.6 m light for every relic in the world, lit gold when
it's delivered, so anyone can look up and see how the crew's doing. Rows: relics for one player, then
two, three and four (by their rings), then a block per group run. It builds itself from the world's
relics. (Later, with more regions: a block per region.)

## Worlds

| World | Purpose |
|---|---|
| `rooftop_district.tscn` | The playground (default). White and grey buildings, a grey street, everything you can use in colour (red vault, yellow climb, blue grind rails, orange ramps and vents); no signs. A 5 x 5 block district: buildings split by 5 m alleys, blocks by 10 m streets, quarters by two 24 m avenues crossing at a plaza (the north-south one has the subway tracks). Built from a seed by `tools/gen_district.gd`, each block rolling its own dice. Alley neighbours differ by at most two storeys (7 m, a readied leap gets you up), towers aside. Sloped roofs are sprinkled about (grey, never on towers or each block's lowest building): old-town terraces of pitched-roof houses (ridges across the row, 1.5 m lanes or touching) and sawtooth sheds (5 m teeth, a gentle slope up to a 1.2 m glass face); free-run slides down them and skims the glass faces. Only flat roofs get fire escapes, rails, checkpoints, relics and clutter. Every block has a yellow fire escape (one-storey solid steps along a street-facing wall of its lowest building), and grind rails cross both avenues from a taller roof down to a lower one (and can be climbed back up). Roofs carry red air-con boxes to vault and grey stairwell huts (kept clear of roof edges, rail run-ups and landings, and checkpoints); pavements have red benches and bins and yellow phone booths (kept clear of fire escapes). Thirty relics come back to a drop-off in the middle of the plaza, for teams of every size: 14 for one player, 8 for two, 5 for three, 3 for four (`RELICS_WANTED`). Each has a stack of gold rings, one per player it takes (`WorldItem.players_needed`). The generator tries a relic on every big flat roof (hovering over it, floating 9.5 m above it, or on a white pillar 7 / 11 / 12.5 / 14 m tall: a leap, then leg-ups from one, two or three friends) and in the streets, asks the reachability checker what each takes from the spawn, keeps enough of each, and writes the checker's answer as the rings. Five are fixed: one floating 18 m over the plaza (launch off a launch roof with a friend who tosses you near the top; it can be caught from 2.5 m away, `items/data/relic_sky.tres`), one over the grind rail nearest the plaza, one on the tallest roof, one on a roof in the far north-east corner, and one on the subway tracks at the north end. Items lie about to try: bats and balloons in the plaza, gliders on the three tallest free roofs, more balloons on the next, crates in the streets (they go home if left lying about). Round the plaza, four orange launch roofs (`levels/ramp.gd`: low buildings, a yellow step and wall at the back, a 25° roof down to a lip 2.5 m up) launch you toward the middle; leaving one sliding goes higher. Ways back up: every other flat-roofed building (towers aside) has a yellow drainpipe (`levels/drainpipe.gd`; climb it at 5 m/s, pulled onto the roof at the top) or a column of yellow window sills (one per storey, 3.5 m apart: hang, then ledge-leap up), and every block an orange air vent on the pavement (`levels/air_vent.gd`) that blows you up beside a building to 1 m above its roof. Towers have no way up yet. R takes you back to a roof checkpoint |
| `free_run_line.tscn` | Training ground. One straight course with every move in order. Built by `tools/gen_free_run_line.sh` |
| `test_course.tscn` | Training ground. Human-scale lab the move tests rely on |

## Reachability (`game/reach/`)

`ReachMap.build(level, profile)` turns a level into places (every walkable box top, seen from above)
and targets (relics), and links them with **rules**, one script each in `game/reach/rules/`: jump
(and drop, and leap, and full-flow jumps, alone or drafting in a pack), scramble, hanging chain, toss, leg-up, crack the whip, catch, drainpipe (and scaffolding: climbed from its foot, or grabbed from a jump across a gap), window sills,
air vent, grind rail, launch roof, glider, touching relics. Each link says what it needs: abilities
or items (`flow`, `glider`), friends who stay behind (a toss, those braced for a leg-up, the rest of a whip's line), friends already there (a chain, a catch), friends going together (a pack's drafting jump).
`solve()` spreads a group out from the start and gives the most players who can get to each spot;
`players_needed()` the fewest for one to get there. Numbers come from the movement profile, so
changing a move changes the answers.

- **A new move or item** = a new rule script, plus a calibration test in `tests/test_reach.gd` that
  plays the real move just inside and just outside its limit and checks the checker agrees.
- **Intent tests** (same file) lock in what a level should be: today, every roof but the towers is
  reachable alone (from the start and from the street), each drainpipe, sill column and vent is a
  way up, each relic's rings match what the checker says it takes, and the towers have no way up.
- **See it:** `tools/reach_view.gd` draws a world from above, each place coloured by the players it
  needs (green 1, yellow 2, orange 3, red 4+, grey nobody).
- What it has taught us: a hanging chain brings the rest of a group up after someone gets there
  another way (a toss, a fire escape...); on its own it can't get the first one up. A readied leap
  scrambles about 1.5 m higher than a jump (10 m walls are just soloable with one). Bigger groups
  get up bigger walls by combining moves: at 12.5 m, three get one player up (a two-high leg-up
  stack) but the two left below are out of a one-friend chain's reach; four get everyone up (two
  run up the stack in turn, then hang down for the others). Across a gap too wide to leap alone,
  two can crack the whip to fling one over, and the one flung over catches the rest, leaping short:
  nobody's left behind (without catching, three could only whip two over). A pack of four
  drafting together can all just leap a gap that size.

## Launchers (`levels/launcher.gd`, Nov 2026)

Orange ramps you run UP and fly off (launch roofs, `Ramp`, are slid down): from 7 m/s, the faster
the higher, 3 to `max_rise` (9) m above the launch point at 16 m/s, plus 2 for a readied leap,
keeping the part of your speed along the ramp. Two shapes: **straight** (a wall ramp: 12 m long, up
to 5 m, built along a building's street side; it throws you up and on, high up the wall, to grab or
scramble onto the roof) and **curved** (a quarter-pipe: radius 5 m, from flat to 75°; you're launched
where it gets 40° steep, along the 75° lip: mostly straight up). Free-run rides them rather than
jumping. The district has four wall ramps (4-5 storey buildings without another way up on that
wall) and two quarter-pipes (at the foot of 4-storey walls); the checker's `launcher` rule links
the street to the roof beside the launch's top (`tests/test_launchers.gd` plays it for real).
Two quarter-pipes facing each other make a half-pipe (none placed yet).

## Pipes (`levels/pipe.gd`, `player/states/pipe_run.gd`, Nov 2026)

Big round tubes: storm drains, road tunnels, glass tubes between towers. Walk or run through on the
floor; run up the side fast enough (past 25°, at 5 m/s or more) and you're running round the inside
(`PipeRun`), like a loop-the-loop. Controls work on the tube unrolled flat (free-running: where the
camera points, so point it across the tube to go round). Gravity round the wall is a gentler 10 m/s²,
and running pushes you on at 3 m/s² (up to your top speed). You stay on while your speed round
holds you there (v² / r >= g down the wall), so near the ceiling too slow and you drop off; slower
still, you swing back down like a half-pipe. Jump: off the wall, in toward the middle. Your body
leans with the wall (upside down on the ceiling) and the camera stays on your head's side. Steering turns you on the wall (up to 3 rad/s, keeping your speed, not while sliding back down), so running in along the tube at full flow and turning the camera across takes you round.
`Pipe.loop_speed()` is the speed round at the bottom to make it over the top (a calibration test
plays either side of it): 11.8 m/s for the 4.5 m road tunnel (full flow only), 9.7 for a 3 m glass
tube (free-running). The district has a glass tube across each avenue, between two roofs the same
height (where rails can't go: they need one higher), and a 40 m road tunnel on the south ring road
with a relic on its ceiling. The checker's `pipe` rule joins a tube's two end places (if level with
its floor) and links them to targets your middle passes going round, needing flow if free-running
isn't fast enough. (Fixing it turned up a launch roof rule that ignored distance: it now only
reaches targets within its flight.)

## Delivery celebrations (`game/celebration.gd`, Nov 2026)

A party at the drop-off when a relic comes in, all particles made in code: confetti (tumbling paper);
streamers (ribbon trails); fireworks (rockets climbing, bursting into trails with a flash of light
and a bang). Its size comes from the delivery's style, scored by the host (`main.gd
delivery_tier()`, `Celebration.tier_for()`): speed (carried: how fast you're seen moving; thrown: how
fast it flew) / 6, up to 3; how far you came down to the drop-off in the last 3 s / 5, up to 4; 1.5
for each friend free-running within 12 m of you; 0.5 for throwing it in. Under 2: "Relic delivered!",
confetti. 2+: "Stylish delivery!", plus streamers. 4+: "Spectacular!", plus 3 fireworks. 6.5+:
"LEGENDARY!", plus 9. Everyone sees the same party (the host sends its size with the delivery).

## Saving progress (`game/progress.gd`, Nov 2026)

The host saves what the crew has done in each world: relics delivered, and group-run relics earned
but not yet delivered, each named by where it is in its world ("Relics/RelicBlock12_1",
"Runs/Run1/Rewards/Finish"). Saved after every delivery and every run that earns something, in
`progress.cfg` beside `settings.cfg`; put back when the world next starts (solo or hosting), so the
hub tower's lights, the counter and the run signs carry on. Joining players get it from the host.
Developers can switch saving off and forget it all in the pause menu (`Settings.save_progress`);
the build friends play always saves. Tests save to `test_progress.cfg`, off unless a test turns it on.

## Building (Nov 2026)

`build_windows.cmd` exports the "Windows" preset (`export_presets.cfg`, committed; tests and tools are
left out, `*.cfg` files are put in) as a release build into `build/windows/`, then runs the built
game with `-- --check-build` (`main.gd check_build()`): it loads every world and checks the outfit
lists, the music and Steam are all there and developer tools are off, writing `build/check.log`.
Steam: the GodotSteam GDExtension (4.23.2, from codeberg.org/godotsteam/godotsteam) is in
`addons/godotsteam/`, Windows and Linux 64-bit only.

**Steam play** (`game/network.gd`, Steam section): with Steam running, the start menu's Host makes a
friends-only lobby (`host_steam()`) and hosts through it with GodotSteam's `SteamMultiplayerPeer`, so
the rest of the game's networking is unchanged; Steam's invite window opens (and Esc > Invite Friends).
Friends join from the invite or "Join Game" (Steam's `join_requested`), or, if the game was closed,
from the `+connect_lobby <id>` Steam starts it with. Without Steam everything works by address as
before, and the tests never start Steam (`Network.steam_allowed`). Until our own app ID is approved,
`STEAM_APP_ID` is 480, Valve's test game "Spacewar" (Steam shows you playing that); swap ours in
there. Checked by hand: hosting makes a lobby and plays through it. Joining needs two Steam accounts,
so it waits for a test with a friend.

## Testing

`run_tests.cmd` runs the gameplay tests (about 140; `run_tests.cmd items` runs just the item ones). New features come with tests, and each
new rule is checked by breaking it on purpose to make sure a test notices.

## Ideas not yet in the master doc

- **Full pipes**: a few round tunnels to run round the walls of at speed (a sewer, a road tunnel,
  a glass observation tube between skyscrapers). Interiors in general: bridges, building floors.
- **More ways up**: scaffolding (stacked platforms, needs a zig-zag layout with grabbable fronts),
  ivy, bounce pads; air vents could pair with a glider. Something for the towers.
- **Co-op moves that scale with player count** (Nov 2026, the user's favourites):
  - **Hanging chain**: built (see "How movement is built").
  - **Leg-up**: built (see "How movement is built"), stacks up to four high.
  - **Crack the whip**: built (see "How movement is built"): a longer line flings harder.
  - **Drafting**: built (see "How movement is built"): a bigger pack builds flow faster and runs
    a little faster, so it jumps a little further.
  - **Catch**: built (see "How movement is built"): a friend at the edge catches you falling short.
  - **Human pyramid**: stand on each other's heads (needs players to collide with each other).
- Hands: only bulky items block hand moves today; zip lines, swing poles and the like could follow
  the same rule (undecided).
- Hold-to-aim toss, players colliding / standing on each other's heads.

## Interiors (`tools/gen_district.gd`, `game/reach/`, Nov 2026)

Built for running through, not offices with doors: wide, tall (a room is two storeys: 6 m), long
sight lines, open doorways and window-openings (no glass), so the third-person camera and full
speed work inside. Mostly larger buildings, as shortcuts through or up. About a quarter of the
district's buildings (16 of 61) are hollow, cut out of their box by "subtract" child boxes
(`Room`, `Door*`, `Opening*`, `Hatch*`), so the outside, the roof and everything on it stay the same:
- **Tower atriums** (all five towers): hollow from the street to the roof, a doorway in three walls,
  and a climb of yellow blocks round the inside walls, each a storey above the last (like a fire
  escape on the inside: a face to grab), the last coming up through a hatch, level with the roof.
  The towers' first way up.
- **Warehouses** (4, 4-5 storeys, 20 m+ wide): one big hall from the street, an 8 x 6 m loading door
  in each wall, red vault boxes clear of the lanes through. A relic up in the air (a friend's toss).
- **Top floors you run through** (7, 6+ storeys): the top two storeys hollow, 6 x 4.5 m openings
  about every 12 m along each wall at floor level: leap in from a roof that height, out the other
  side. A few have a relic in the middle.
Openings slide along a wall to keep clear of fire escapes, drainpipes, sills, vents and launchers
(the way onto the roof stays), and the pavement keeps clear in front of them.

The checker knows about inside: buildings are solid apart from their holes; a `Room` hole's floor
is a place ("Building/Room", unless it's the street); and a link only counts if a path between
its two spots (taking off from the place itself with room overhead, up to above the higher one,
across, down) stays clear of walls and ceilings (`ReachMap.path_clear()`). Only buildings block
(in a "Buildings" node, or the `reach_solid` group). Interior relic spots are tried before roofs.
Later: parking garages, hallways between buildings.

## Shapes (`tools/gen_district.gd`, `game/reach/`, Nov 2026)

Not every building is a box. A building is CSG shapes joined (a box, an upright cylinder, a
sphere, added into it as children) less holes (subtract boxes). Twelve of the district's 61:
- **Round**: a rotunda (a cylinder) on a squarish lot, half of them with a dome; on a long lot, a
  box with a half-round end each way. You scramble straight up the curved wall.
- **Domed**: a shallow dome on the roof. Its middle is sunk 3/4 of its radius under the roof, so it
  is never steeper than about 41 degrees: you run right up it and over.
- **Stepped**: one or two tiers on top, each set back 4 m and two storeys tall (a scramble up each).
- **Courtyard**: a yard down through the middle (the building a ring 8 m deep), with a 6 x 5 m arch
  through from one side.
- **Winged**: an L, a corner cut out.
They're dealt out in turn so there's some of each, from buildings that would otherwise be sloped
or flat, but never a block's lowest, nor a flat roof facing an avenue (rails and tubes cross there).
Like sloped roofs they get none of the flat roofs' things (fire escapes, clutter...). Relic spots on
them: on top of a dome, a tier or a round roof, over a courtyard, and higher over each (floating
over a dome, on a tall pillar otherwise). Tests tell them apart by `metadata/shape`.

The checker reads the shapes: each one's top is a place (a box's, less holes cut down through it
and other parts standing on it, split into rectangles; a cylinder's as two rectangles crossed; a
dome's crown, `DOME_CROWN` under its top), named after it or "Building/Part" (pieces "#2", "#3"
...); cylinders and spheres are round when it checks a path is clear; and getting onto or off
something on top of a place, it tries taking off or landing a few metres out round it (a dome's foot).

### Angles and styles (groundwork for the museum and the futuristic quarter)

The checker works each shape out in its own space, so a shape can be turned, tilted or stretched
any way, and there's a fourth kind, a **prism** (a `CSGPolygon3D`: an outline pushed out, like a
curved wall seen from above or a wedge seen side-on). Tops it can't take straight off a box,
upright cylinder or round dome, it looks down on in 0.5 m squares (`_sloped_tops()`): where the top
is no steeper than 10 degrees (`STAND_SLOPE`, the slope free-run starts sliding down), you can stand.
Those squares are joined into the biggest rectangles of about the same height (a tilted roof is
a few strips, a small step up from one to the next), leaving out any less than 1.5 m wide (a ridge,
the top of a pipe). And walls: a scramble, a leg-up or grabbing an edge from a jump needs the wall
under the edge to be within 15 degrees of upright (`WALL_LEAN`, `wall_up()`). In the game a face
more than about 17 degrees off upright isn't a wall you can grab (`Player.find_ledge()`): leaning out
over you, you hit it; leaning back, it's a steep slope. Tests: `tests/test_angles.gd` (a building
turned 30 degrees, one leaning 6 and one 20, a curvy prism, a flattened dome, walls leaning out 6
and 25 degrees and back 25, a "mushroom" overhanging all round, a thin wall's top), each checked
in the game too.

The generator has **styles**. The south-east quarter (past both avenues) is **modern**, with denser
blocks (four lots each) and its own shapes, dealt out to every building there that can have one:
- **Turned**: turned 12-25 degrees in its lot, as big as fits.
- **Leaning**: tilted 6 degrees toward one side, its foot sunk in the ground, narrowed so its top
  stays over its lot; its top is gently sloped strips and one wall leans out over you.
- **Curved**: its long sides wave in and out (a museum's curving walls).
- **Cantilever**: its top two storeys stick out 3 m over a street (never an avenue or the ring
  road: rails, tubes, the tunnel), at least 7 m up; a relic sits at the tip.
- **Round** (as in the old town).
The rest is the **old town** (round, domed, stepped, courtyard, winged).
Since built: the museum and downtown (below). Next: a church or
cathedral, parking garages, hallways.

### Slopes and the museum

**Slopes you run up.** In the game you can run up anything up to about 45 degrees (the physics'
floor limit; steeper and you slide back down). The checker says 40 (`RUN_SLOPE`, a little margin):
every stretch of a shape's top between 10 and 40 degrees, uncovered and with 1.6 m of headroom, is a
**slope** (`ReachMap.Slope`, `_find_slopes()`), and `rules/run_up.gd` links the places it meets at
its foot and its top, both ways ("run up", "run down"). Nothing is jumped, so no jump path to clear.
Pitched old-town roofs (28-36 degrees) count too: run up one to a taller roof at its ridge. The
checker also reads **spun** shapes (a `CSGPolygon3D` outline spun round an upright line: a ring, or
an arc of terraces), and covered bits of a sloped or curved top are worked out exactly (anything
else of the building just over it), not by boxes. Tests: `tests/test_slopes.gd` (30, 40 and 46
degree slopes, run up in the game: 40 yes, 46 no; one with a slab over it; terraces spun round).

**The museum** (after the Canadian Museum of History: curved layers like rock laid down by a
glacier, a great hall, copper domes) fills the south-west block on the road round the district
(`MUSEUM_*` in the generator). In the middle, a round hall 24 m tall with a flattened dome on top
you run up to its crown. Round it, terraces spun in arcs, each a slope (36 degrees at its steepest,
curving over into its top) you run straight up from the street: the gallery (to 10 m), the upper
terrace on it (to 18 m), and a low wing (5 m) either side. Relics on the terraces' tops and floating
over the dome. Tests: `tests/test_museum.gd` (keeps to its block; slopes runnable; every top
reachable alone; in the game, up both terraces from the street, and up the dome).

### Downtown

East of the old town, across a boulevard as wide as an avenue (`DOWNTOWN_*` in the generator),
after the user's own concept art: tall modern towers packed close, roofs at all heights, busy with
things to vault and climb, and coloured parkour kit in the gaps. A first try (a "futuristic
skyline": six skyscrapers on podiums, 24 m avenues, sky lifts, spiral ramps, 60 m glass bridges) was
too spread out and too sci-fi; this replaces it.

- **Towers**: 32 of them in a grid, each 16-24 m across, most an **alley** (5 m, a running jump)
  from the next, some a **street** (10 m, a readied leap). 14-30 storeys, taller toward the middle;
  the column by the boulevard stays under 18 (it steps up from the old town). The **spire** in the
  middle is 140 m, with a terrace round it at 105 m. About a third have a lower **wing** on one
  side (3-6 storeys lower) with a drainpipe from it up to the top. You run it high up, roof to roof;
  the street is a deep canyon below.
- **Roofs** are busy: closer to the edges and more of them than in the old town, red vaults (some
  long, like ducts), stairwell huts.
- **Scaffolding** (yellow, `levels/scaffold.gd`): up every tower from the street, on a wall facing a
  lower neighbour if it has one. It climbs like a drainpipe, but anywhere across its 3 m face, and
  you can **grab it mid-jump** from the roof across the gap (the checker's drainpipe rule now knows
  that: from a place in front of the face, in reach of a running jump or a readied leap, at a height
  you can hold on at). Every tower top can be reached alone this way.
- **Grind rails** (blue): ten, from a roof across a gap down to one 1-3 storeys lower, starting 8 m
  in from the edge (on the roof) and ending 6 m in.
- **Rope bridges**: five, across streets between towers the same height: a level deck of rainbow
  rope netting (`materials/net.tres`) with a hand-rope either side, sagging (to look at). Level,
  because the checker reads a gently sloping plank as two strips too small to stand on.
- **Catch nets** (`levels/catch_net.gd`): eight, sticking out of a wall over an alley, 3 storeys
  under its roof, nearly to the far side. Miss a jump and one catches you, then bounces you back up,
  drifting in to the wall, onto the roof (or grab its edge). Rule: `rules/catch_net.gd`.
- **Walkways**: two covered walkways (glass sides) across alleys, joining a floor inside each
  tower: two storeys tall, openings 6 m tall all round (room to jump in at full height), level with
  a lower roof next door, so you jump in from it, run through and across. Openings keep clear of
  scaffolding and drainpipes.

Nothing sci-fi: no sky lifts, spirals or long glass bridges. Relics: on the four tallest tops (the
spire's too), in each walkway, floating over the spire (a toss up from its top) and over a rope
bridge (a toss up from it). They're always there (like the five fixed ones) and `RELICS_WANTED`
counts them, so the old town keeps the same relics. A checkpoint on a tower by the boulevard.
Tests: `tests/test_downtown.gd` (packed close across the boulevard; heights; no sci-fi; every top
alone; scaffolding up every tower; rails, rope bridges, nets and walkways joined up; and in the game:
jump across a gap onto scaffolding and climb it, walk a rope bridge, fall into a catch net and bounce
back onto the roof, leap from a roof into a walkway floor).

Still to come here: wingsuit courses off the tops (see the ideas backlog), and the hub tower is now
dwarfed (56-60 m against towers up to 140 m), so it should grow to stay a landmark.

## Scale: the stress city (`levels/stress_city.gd`, `tools/bench_city.gd`, Nov 2026)

How big can a one-load world go? A throwaway city built in code as it loads (in the start menu as
"Test: Stress City"): the old town round the west rising to a 150 m round hub tower with a beacon,
and a futuristic quarter to the east (40-200 m, two at 260 and 300 m, round, stepped, hollow ones
with sky lobbies, glass bridges over the avenues, whole-block halls). Each 300 m chunk's buildings
are joined and baked into one mesh and one collision shape (`CSGShape3D.bake_static_mesh()`).
Measured 4 Nov 2026 (RTX 4070, Ryzen 9800X3D, 1920x1080, vsync off; worst view = the whole city from above):

| Across | Buildings | Load (built + baked at load) | Worst view | Memory |
|---|---|---|---|---|
| 3 km | 4,100 | 5 s | 1,300 fps, 270 draw calls | 200 MB |
| 6 km | 16,300 | 18 s | 900 fps, 1,100 draw calls | 460 MB |
| 10 km | 44,900 | 51 s | 470 fps, 3,100 draw calls | 1.1 GB |

Not baked (each building its own CSG shape, like the rooftop district), 3 km: 420 fps from above
(4,400 draw calls), so baking matters as it grows. Occluders (hiding what's behind buildings) cost
more than they saved here. What it means: drawing isn't the limit at any of these sizes (and these
are plain boxes: real art will cost more, but there's lots of room). The limits are load time (bake
ahead and ship the meshes, or load chunks as you go, rather than building at load), the
reachability checker (it compares every place with every other: it needs sorting by area before a
city this size), and how much there is to fill: 10 km is 11 minutes across at full flow.

## Light trails (`player/light_trail.gd`, `materials/light_trail*.gdshader`, Nov 2026)

For a city kilometres across: how you find your friends when they're too far off to see. Every
player leaves a ribbon of light in their colour along where they've run (a point every 0.75 m at
their middle), each bit lasting 20 s and fading over its last 5; a respawn starts a new one. The
shader turns it to face the camera and keeps it at least `screen_width` of the view wide however far
off (about 8 pixels at 1080p), so it isn't big up close but reads from across the city; it's unshaded,
ignores the haze, is faint right by the camera, and is drawn again at half strength through walls.
Every screen draws everyone's from where it sees them (nothing extra on the network). A setting
turns them off. The cloth trails (banners, scarves: `player/trail.gd`) are still cosmetics up close.
The stress city is now 4 km across by default.
