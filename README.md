# Parkour Friends

Third-person co-op parkour game made with Godot 4.7 (GDScript).

## Running it

1. Double-click **`open_editor.cmd`** to open the Godot editor. (Double-clicking the Godot exe itself runs the
   game instead, because it notices the project in its folder. The exe is not committed to Git.)
2. Press **F5** (or the ▶ "Run Project" button at the top right) to play. Pick a **World** (Old Town, or the
   Test Course playground), then **Play Solo** or **Host**. Joining players get the host's world.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Sprint | Shift | Click left stick |
| Crouch / slide (crouch while running) | C or Ctrl (hold) | B / Circle |
| Slide-jump (keeps your speed) | Space during a slide | A |
| Wall jump (not the same wall twice before landing) | Space in the air next to a wall | A |
| Wall run | Sprint, jump alongside a tall wall, hold forward | |
| Toss a friend (aim with the camera; mid-air toss gives you a hop too) | E | Right bumper |
| Solo practice: call your buddy / have it toss you | G / Q | D-pad down / Left bumper |
| Jump (hold for higher) | Space | A / Cross |
| Grab a ledge | Jump at a wall while pushing toward it | |
| Climb up / shimmy / let go (while hanging) | Space / A, D / C or Ctrl | A / left stick / B |
| Camera | Mouse or arrow keys | Right stick |
| Respawn at checkpoint | R | Back / Select |
| Pause menu (sensitivity, invert, leave, quit) | Esc | Start |
| Hide help | F1 | |

## Project layout

Folders are organized by *feature*: each scene (`.tscn`) sits next to its script (`.gd`).

```
game/       main.tscn + main.gd   – menu → solo/host/join, loads the level, spawns players
            network.gd            – hosting, joining and leaving online games
player/     player.tscn           – the character
            player.gd             – settings + shared movement helpers + ledge detection
            player_input.gd       – turns keyboard/gamepad into plain variables
            camera_rig.gd         – third-person orbit camera
            ledge.gd              – data about a grabbable ledge
player/states/                    – one script per movement "mode" (state machine):
            player_state.gd       – base class every state extends
            ground.gd, air.gd     – running; jumping/falling (+ starts ledge grabs)
            hang.gd, climb.gd     – hanging/shimmying; pulling up / vaulting
            crouch.gd, slide.gd   – crouch-walking; sliding (slopes speed you up)
            wall_run.gd           – running along walls (wall jumps live in air.gd)
levels/     old_town.tscn         – the first slice: Old Town hub + Ancient Greece island (see docs/)
            test_course.tscn      – grey-box playground for each move (the tests use it)
            level.gd              – base level script (spawn points)
            checkpoint.tscn/.gd   – drop-in respawn checkpoint
ui/         hud.tscn/.gd          – debug overlay (state, speed, height, network, controls)
            main_menu.tscn/.gd    – start menu
materials/  grid.gdshader + .tres – grey-box materials with a 1 m grid
```

Physics layers (Project Settings → Layer Names → 3D Physics): 1 = world, 2 = players, 3 = triggers.

## Adding a new move

1. Create `player/states/<move>.gd` that `extends PlayerState` and fill in `enter`, `physics_update`, `exit`.
2. In `player.tscn`, add a `Node` under **States** with that name and attach the script.
3. From another state, switch to it with `player.change_state(&"<Name>")`.

## Multiplayer

**Trying it on one computer:** in the Godot editor, open the **Debug** menu → **Customize Run Instances…**,
tick **Enable Multiple Instances**, set the count to **2**, and click **OK**. Now **F5** opens two game windows:
click **Host a Game** in one and **Join** (address `127.0.0.1`) in the other.

**Shortcut:** launching with `-- --solo`, `-- --host` or `-- --join=ADDRESS` skips the menu
(in Customize Run Instances, put these in each instance's *Launch Arguments*).

**How it works:**
- One player **hosts**; others **join** them (ENet over UDP port 7777, up to 4 players). See `game/network.gd`.
- **Each player's own computer runs their character's movement** and publishes `sync_position`,
  `sync_facing` and `sync_state`. The `NetworkSync` node (a `MultiplayerSynchronizer`) sends those to everyone
  else, where the character is a smoothed "puppet". Simple and responsive; fine for co-op, where nobody needs
  to be stopped from cheating.
- **Characters are named after their player's network id** (`1` = the host). Only the host creates and removes
  them (`main.gd`); the `PlayerSpawner` node (a `MultiplayerSpawner`) copies them to everyone, including people
  who join later.
- **A new move needs nothing extra for multiplayer** unless it changes something other players must see
  beyond position, facing and state; then add it to the `sync_*` variables and the NetworkSync node.
- **Players don't collide with each other** (or block each other's cameras) yet. That's a design choice to
  revisit for co-op, e.g. boosting a friend up a wall.
- **Tossing** (`try_toss` / `receive_toss` in `player.gd`): the thrower's computer picks a friend in reach and
  sends their owner a `receive_toss` RPC; the owner checks the thrower is nearby and applies the launch. Once
  per air time each player can toss once and be tossed once (`limit_tosses_per_air` turns that off).
- **Practice buddy** (solo only, `call_buddy` / `buddy_toss_me` in `main.gd`): a grey `Player` with `is_bot` set,
  run by this computer with no camera or controls, for practising tosses alone.
- **Each player gets their own colour**, chosen by the host and sent to everyone by the `HostSync` node
  (the one synchronizer the host controls, rather than the character's owner).
- **Not done yet:** playing over the internet (needs port forwarding, a relay, or Steam).
## Automated tests

`tests/` holds gameplay tests that play the game in code (no window) and check the results:
speeds, jump height, ledge grabs, slides, wall moves, tossing, checkpoints, menus, and multiplayer (a host and a joiner run
side by side in one program and must see each other move).

- **Run them:** double-click `run_tests.cmd`, or run it from a terminal. It prints PASS/FAIL for each test.
- **Run them after every change** to make sure nothing that used to work has broken.
- **Add a test:** add a `func test_something() -> void:` to a `tests/test_*.gd` file (or make a new one).
  The helpers in `tests/game_test.gd` (`place`, `hold`, `tap`, `run_and_jump`, `expect`, …) do most of the work.
- **Two-player tests** extend `MultiplayerTest` (`tests/multiplayer_test.gd`), which provides `host_main` and `client_main`.
