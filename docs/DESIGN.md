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
  Background music: each world names its song (`Level.music`, set by the level generators), which
  loops; M mutes it and the pause menu has a volume slider (both saved in Settings).
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
| Run speed / top speed with full flow | 10 / 15 m/s |
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

Kept to a handful of buttons, each doing whatever fits where you are: E is everything with a
friend (toss, brace, shoulders, take a hand), F everything with items (tap: pick up / drop / hand
over; hold 0.3 s: throw, `PlayerInput.THROW_HOLD`), C crouches, slides and lets go. Many moves have
no button at all (catch, crack the whip, ledge grabs, wall moves, drainpipes). Free-run stays a
held button, so you only join a pack when you mean to. On screen: a short card in a corner (F1
hides it) and one prompt for what a button would do right now, from `Player.control_hints()` (moves)
and `ItemCarrier.control_hints()` (items, with each ability's `use_hint()`); both name the keyboard
or gamepad control, whichever was used last (`ui/control_names.gd`). Developer tools (practice
buddy G / Q / H, outfits O, readout F3) only work when `Settings.dev_tools` is on: running from the
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
- One slot for everyone: your **hands** (the item's ability runs there). A **backpack** is
  worn, not held, and adds a second slot to stow an item in (right click swaps; F held throws). A new item goes in your
  hands and pushes the current one into the backpack; with no room, F drops instead. F with
  empty hands takes the backpack off (what was in it comes out into your hands).
- **Bulky** items (the crate now, the glider later) need both hands: no ledge grabs, climbs,
  vaults or scrambles while one is in your hands, and you let go if one lands in your hands
  mid-climb. Stow it in a backpack to climb. Wall runs, wall jumps and grind rails still work
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
  hands) and a **Backpack**, at the start of the Free-Run Line.
- Item list (Oct 2026, see the master doc): glider, grappling hook, baseball bat (send a friend
  a long way), pogo stick (clumsy), backpack. Dropped: parachute, running shoes, roller skates,
  suction-cup hands (for now). Tools are always used by hand: free-run never uses them.

## Worlds

| World | Purpose |
|---|---|
| `rooftop_district.tscn` | Default. A 5 x 5 block district: buildings split by 5 m alleys, blocks by 10 m streets, quarters by two 24 m avenues crossing at a plaza (the north-south one has the subway tracks). Built from a seed by `tools/gen_district.gd`, each block rolling its own dice. Alley neighbours differ by at most two storeys (7 m, a readied leap gets you up), towers aside. Sloped roofs are sprinkled about (grey, never on towers or each block's lowest building): old-town terraces of pitched-roof houses (ridges across the row, 1.5 m lanes or touching) and sawtooth sheds (5 m teeth, a gentle slope up to a 1.2 m glass face); free-run slides down them and skims the glass faces. Only flat roofs get fire escapes, rails, checkpoints, relics and clutter. Every block has a yellow fire escape (one-storey solid steps along a street-facing wall of its lowest building), and grind rails cross both avenues from a taller roof down to a lower one (and can be climbed back up). Roofs carry red air-con boxes to vault and grey stairwell huts (kept clear of roof edges, rail run-ups and landings, and checkpoints); pavements have red benches and bins and yellow phone booths (kept clear of fire escapes). Five relics come back to a drop-off in the middle of the plaza: one floating 18 m over the plaza (launch off a launch roof with a friend who tosses you near the top; it can be caught from 2.5 m away, `items/data/relic_sky.tres`), one over the grind rail nearest the plaza, one on the tallest roof, one on a roof in the far north-east corner, and one on the subway tracks at the north end. Round the plaza, four orange launch roofs (`levels/ramp.gd`: low buildings, a yellow step and wall at the back, a 25° roof down to a lip 2.5 m up) launch you toward the middle; leaving one sliding goes higher. Ways back up: every other flat-roofed building (towers aside) has a yellow drainpipe (`levels/drainpipe.gd`; climb it at 5 m/s, pulled onto the roof at the top) or a column of yellow window sills (one per storey, 3.5 m apart: hang, then ledge-leap up), and every block an orange air vent on the pavement (`levels/air_vent.gd`) that blows you up beside a building to 1 m above its roof. Towers have no way up yet. R takes you back to a roof checkpoint |
| `free_run_line.tscn` | One straight course with every move in order. Built by `tools/gen_free_run_line.sh` |
| `test_course.tscn` | Human-scale lab the move tests rely on |

## Reachability (`game/reach/`)

`ReachMap.build(level, profile)` turns a level into places (every walkable box top, seen from above)
and targets (relics), and links them with **rules**, one script each in `game/reach/rules/`: jump
(and drop, and leap, and full-flow jumps, alone or drafting in a pack), scramble, hanging chain, toss, leg-up, crack the whip, catch, drainpipe, window sills,
air vent, grind rail, launch roof, glider, touching relics. Each link says what it needs: abilities
or items (`flow`, `glider`), friends who stay behind (a toss, those braced for a leg-up, the rest of a whip's line), friends already there (a chain, a catch), friends going together (a pack's drafting jump).
`solve()` spreads a group out from the start and gives the most players who can get to each spot;
`players_needed()` the fewest for one to get there. Numbers come from the movement profile, so
changing a move changes the answers.

- **A new move or item** = a new rule script, plus a calibration test in `tests/test_reach.gd` that
  plays the real move just inside and just outside its limit and checks the checker agrees.
- **Intent tests** (same file) lock in what a level should be: today, every roof but the towers is
  reachable alone (from the start and from the street), each drainpipe, sill column and vent is a
  way up, the sky relic needs two players and the others one, and the towers have no way up.
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

## Testing

`run_tests.cmd` runs the gameplay tests (about 140; `run_tests.cmd items` runs just the item ones). New features come with tests, and each
new rule is checked by breaking it on purpose to make sure a test notices.

## Ideas not yet in the master doc

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
