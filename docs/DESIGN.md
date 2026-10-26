# Parkour Friends: technical design notes

**The master design document is the Claude doc
["Parkour Friendslop – Game Design Doc"](https://claude.ai/artifact/FaCnq4frncwnN9L2MgsfSU).**
It holds the vision, world, items, puzzles, progression, multiplayer and roadmap. Where this
file and the Claude doc disagree, the Claude doc wins. This file only records how things are
built and the details the code relies on.

## Decisions reflected in the code (Oct 2026)

| Decision | What it means in the code |
|---|---|
| One big city | The floating-islands prototype (`levels/old_town.tscn`) is obsolete; the Free-Run Line is the default world for now |
| Free-run stays | `player/free_run.gd`, switchable in the pause menu |
| Throw chains are rewarded | You can toss once per air time, and each friend can toss you once per air time (`tossed_by` in `player.gd`) |
| Base moves never change | No agility levels; relics are only collectibles (carry-back deliveries are in the master doc, not built yet) |
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
- **Flow** builds while you keep moving at speed and drains only on the ground (stopping,
  letting go, crashing). Vaults come out at flow speed.

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
  character and shares position, facing, state, lean and who has tossed them.
- The host owns world state (relics found) and picks the world; joiners receive it.
- The host owns every item: it runs their physics and decides who holds what, so two players
  grabbing at once can't both get it. Players' computers only ask (`request_pick_up`,
  `request_drop`, `request_throw`).

## Items (groundwork)

- Items are real physics objects (`WorldItem`, a RigidBody3D). Each kind is an `ItemData`
  resource plus an optional `ItemAbility` script, so new items need no changes to shared code.
- Two slots: **hands** (active; its ability runs) and **back** (carried, does nothing). A new
  item goes in your hands and pushes the current one to your back; with both full, F drops.
- Throwing: items fly where the camera points. A thrown item passing within 1.3 m of a friend's
  chest is caught if they have a free slot (you can't catch your own for 0.4 s). Dropped items
  can't be caught. F while facing a friend within 2 m hands the item over.
- Items go home after falling below the kill height, after 90 s lying away from home, or
  when the player holding them leaves the game.
- Placeholders only: **Crate** (no ability) and **Test Balloon** (slows your fall while in your
  hands), at the start of the Free-Run Line. The real item list comes from the master doc, which
  also has a note to revisit items now that free-run changed how movement works.

## Worlds

| World | Purpose |
|---|---|
| `free_run_line.tscn` | Default. One straight course with every move in order. Built by `tools/gen_free_run_line.sh` |
| `test_course.tscn` | Human-scale lab the move tests rely on |
| `old_town.tscn` | Obsolete floating-islands prototype (kept until the city exists) |

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
