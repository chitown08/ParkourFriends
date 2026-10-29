# Parkour Friends: technical design notes

**The master design document is the Claude doc
["Parkour Friendslop – Game Design Doc"](https://claude.ai/artifact/FaCnq4frncwnN9L2MgsfSU).**
It holds the vision, world, items, puzzles, progression, multiplayer and roadmap. Where this
file and the Claude doc disagree, the Claude doc wins. This file only records how things are
built and the details the code relies on.

## Decisions reflected in the code (Oct 2026)

| Decision | What it means in the code |
|---|---|
| One big city | The floating-islands prototype (Old Town) was removed; the Free-Run Line is the default world for now |
| Free-run stays | `player/free_run.gd`, switchable in the pause menu |
| Throw chains are rewarded | You can toss once per air time, and each friend can toss you once per air time (`tossed_by` in `player.gd`) |
| Base moves never change | No agility levels; relics are collectibles you carry back to a drop-off |
| Puzzles, not the clock | No timers or time trials |

## How movement is built

- **States** (`player/states/`): one script per mode: Ground, Air, Hang, Climb, Crouch, Slide,
  WallRun, WallScramble, Zipline. Only the active state runs; it decides how to move and when
  to switch (`player.change_state()`).
- **Movement profiles** (`player/profiles/`): every feel number lives in a profile.
  `superhuman.tres` is the default; `human.tres` keeps realistic numbers and is what the
  move tests on the test course use.
- **Free-run** is a co-pilot that presses buttons on `PlayerInput` (jump, crouch); every
  automatic move is a normal move a player could do by hand.
- **Free-run leap**: in free-run your jump button readies a leap while held (0.3 s for a full
  one) and takes off when you let go, or at the next edge or obstacle free-run would jump. A full
  leap is 4.5 m high (a jump is 3) and adds 3 m/s forward: enough to clear the 10 m gap without
  full flow. A tap (under 0.1 s) is a normal jump. Numbers: the "Leap" group in the movement profile.
- **Flow** builds while you keep moving at speed and drains only on the ground (stopping,
  letting go, crashing). Vaults come out at flow speed.
- **Looks and sounds are stand-ins** until there are real animations and recordings.
  `Player._pose_visual()` squashes, stretches and tilts the body model: squashed while crouched
  or readying a leap, stretched by a jump, squashed by a landing, tipped forward and banking while
  gliding; the bat sweeps round in an arc (`item_anchor()`), and whoever it hits flashes white.
  Sounds are made from code (`game/sfx.gd`) and bursts of bits (dust, the bat's "pop") by
  `game/effects.gd`. One-off effects reach everyone through `Player.show_effect()`.

| Rule the levels depend on (superhuman profile) | Value |
|---|---|
| Run speed / top speed with full flow | 10 / 15 m/s |
| Full jump | ~3 m |
| Highest ledge you can grab from a jump | ~5.6 m |
| Wall scramble | ~3.5 m up, once per wall until you land |
| Ledge leap (from a hang-only sill) | up to 4.5 m |
| Toss | ~8 m up, ~8 m/s in the camera's direction |
| Zipline top speed | 26 m/s |

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
  worn, not held, and adds a second slot to stow an item in (Tab swaps). A new item goes in your
  hands and pushes the current one into the backpack; with no room, F drops instead. F with
  empty hands takes the backpack off (what was in it comes out into your hands).
- **Bulky** items (the crate now, the glider later) need both hands: no ledge grabs, climbs,
  vaults, scrambles or ziplines while one is in your hands, and you let go if one lands in your
  hands mid-climb. Stow it in a backpack to climb. Wall runs and wall jumps still work.
- **Relics** are items: they hover at home until touched (touching picks them up if your hands
  are free), and only count once carried or thrown into a drop-off (`levels/drop_off.tscn`,
  beside the Free-Run Line's spawn). A relic you drop or throw needs F to pick up again.
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
| `free_run_line.tscn` | Default. One straight course with every move in order. Built by `tools/gen_free_run_line.sh` |
| `test_course.tscn` | Human-scale lab the move tests rely on |

## Testing

`run_tests.cmd` runs the gameplay tests (about 140; `run_tests.cmd items` runs just the item ones). New features come with tests, and each
new rule is checked by breaking it on purpose to make sure a test notices.

## Ideas not yet in the master doc

- **Street-level launchers** (bounce pads, air vents) to get back up to rooftops; air vents pair
  with a glider.
- **Climbable surfaces** (drainpipes, ivy, scaffolding) you can climb at speed.
- **Free-run at walls too tall to climb head-on**: it stops today; options are an automatic
  wall-jump or turning to run along the wall. The manual moment there feels a bit clunky.
- Hold-to-aim toss, players colliding / standing on each other's heads.
