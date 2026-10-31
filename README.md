# Parkour Friends

**Design:** the master design document is the Claude doc
["Parkour Friendslop – Game Design Doc"](https://claude.ai/artifact/FaCnq4frncwnN9L2MgsfSU);
[docs/DESIGN.md](docs/DESIGN.md) has the technical notes.

Third-person co-op parkour game made with Godot 4.7 (GDScript).

## Running it

1. Double-click **`open_editor.cmd`** to open the Godot editor. (Double-clicking the Godot exe itself runs the
   game instead, because it notices the project in its folder. The exe is not committed to Git.)
2. Press **F5** (or the ▶ "Run Project" button at the top right) to play. Pick a **World** (the Rooftop District, the Free-Run Line, or the
   Test Course playground), then **Play Solo** or **Host**. Joining players get the host's world.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Flow (momentum) | Keep moving: you build from 10 to 15 m/s; stopping or crashing drains it | |
| Free-run (auto-parkour; let go for manual control) | Hold Shift | Hold right trigger |
| Free-run leap: tap jump = normal jump; hold jump to ready a leap, let go (or reach an edge) to take off | Space (hold) | A / Cross (hold) |
| Crouch / slide (crouch while running) | C or Ctrl (hold) | B / Circle |
| Slide-jump (keeps your speed) | Space during a slide | A |
| Wall jump (not the same wall twice before landing) | Space in the air next to a wall | A |
| Wall run | Run fast, jump alongside a tall wall, hold forward | |
| Wall scramble (once per wall) | Jump into a too-tall wall and keep pushing | |
| Ledge leap | While hanging from a narrow sill, jump | A |
| Grind rail | Land on it (from above) and it slides you down; push up it to climb (slower), jump to hop along or leave, C to step off | Hands stay free |
| Toss a friend (aim with the camera; mid-air toss gives you a hop too) | E | Right bumper |
| Solo practice: call your buddy / have it toss you | G / Q | D-pad down / Left bumper |
| Item: pick up / drop (or hand to the friend you face; empty hands: take off backpack) | F | X / Square |
| Item: throw (where the camera points; friends can catch it) | T | Y / Triangle |
| Item: swap your hands and backpack (once you wear one) | Tab | D-pad right |
| Item: use the one in your hands (glider: hold in the air to glide; bat: swing) | Right mouse | Left trigger |
| Jump (hold for higher) | Space | A / Cross |
| Grab a ledge | Jump at a wall while pushing toward it | |
| Climb up / shimmy / let go (while hanging) | Space / A, D / C or Ctrl | A / left stick / B |
| Camera | Mouse or arrow keys | Right stick |
| Respawn at checkpoint | R | Back / Select |
| Music on/off (volume is in the pause menu) | M | |
| Pause menu (sensitivity, invert, leave, quit) | Esc | Start |
| Hide help | F1 | |

## Project layout

Folders are organized by *feature*: each scene (`.tscn`) sits next to its script (`.gd`).

```
game/       main.tscn + main.gd   – menu → solo/host/join, loads the level, spawns players
            network.gd            – hosting, joining and leaving online games
player/     player.tscn           – the character
            player.gd             – shared movement helpers, flow, ledge detection, tossing
            movement_profile.gd   – all the movement numbers; profiles/ has superhuman + human
            player_input.gd       – turns keyboard/gamepad into plain variables
            camera_rig.gd         – third-person orbit camera
            ledge.gd              – data about a grabbable ledge
player/states/                    – one script per movement "mode" (state machine):
            player_state.gd       – base class every state extends
            ground.gd, air.gd     – running; jumping/falling (+ starts ledge grabs)
            hang.gd, climb.gd     – hanging/shimmying; pulling up / vaulting
            crouch.gd, slide.gd   – crouch-walking; sliding (slopes speed you up)
            wall_run.gd           – running along walls (wall jumps live in air.gd)
            wall_scramble.gd      – running up a too-tall wall
            grind.gd              – grinding a rail
            glide.gd              – gliding (started by the glider item, items/abilities/glide.gd)
levels/     rooftop_district.tscn – a 5 x 5 block grey-box district with two crossing avenues (default
                                    world; regenerate with tools/gen_district.gd, see the top of that file)
            free_run_line.tscn    – straight test course with every move in order (regenerate with
                                    tools/gen_free_run_line.sh)
            test_course.tscn      – grey-box playground for each move (the tests use it)
            level.gd              – base level script (spawn points)
            checkpoint.tscn/.gd   – drop-in respawn checkpoint
            drop_off.tscn/.gd     – where relics are delivered (team-shared count in game/main.gd)
            grind_rail.tscn/.gd   – a grind rail (set its end_point)
items/      world_item.tscn/.gd   – a physical item in the world (the host decides who holds it)
            item_data.gd          – what kind of item it is: name, looks, weight, throw speed, ability
            item_ability.gd       – base class for what an item does while in your hands
            data/                 – one .tres per kind of item (relic, backpack, glider, bat, crate, test_balloon, …)
            models/               – item models (relic_gem.tscn)
            abilities/            – ability scripts (glide.gd, bat_swing.gd, slow_fall.gd, …)
player/     item_carrier.gd       – your item slots (hands, plus a backpack if you wear one) and the item buttons
ui/         hud.tscn/.gd          – debug overlay (state, speed, height, network, controls)
            main_menu.tscn/.gd    – start menu
materials/  grid.gdshader + .tres – grey-box materials with a 1 m grid (yellow grid_climb = climbable)
audio/music/ test_level.mp3        – background music (made by Graham in Suno; a world picks its song with Level.music)
```

Physics layers (Project Settings → Layer Names → 3D Physics): 1 = world, 2 = players, 3 = triggers, 4 = items.

## Adding a new move

1. Create `player/states/<move>.gd` that `extends PlayerState` and fill in `enter`, `physics_update`, `exit`.
2. In `player.tscn`, add a `Node` under **States** with that name and attach the script.
3. From another state, switch to it with `player.change_state(&"<Name>")`.

## Adding a new item

Every item is the same physical object (`items/world_item.tscn`); what makes a crate a crate is
its **ItemData** file.

1. **Describe it:** in the FileSystem panel, right-click `items/data/` → **Create New → Resource…**,
   pick **ItemData**, save it as e.g. `glider.tres`. In the Inspector set its name, size,
   colour, weight (mass) and throw speed. (Optional: drag a 3D model scene into **Model** to
   replace the box.) Under **Carrying**, tick what applies: **Bulky** (needs both hands, so no
   climbing while holding it), **Is Backpack**, **Pick Up On Touch**, **Hovers At Home** and
   **Deliverable** (counts at a drop-off, like relics).
2. **Give it an ability (optional):** make `items/abilities/<name>.gd` that `extends ItemAbility`
   and fill in any of `equipped`, `unequipped`, `physics_update` (every tick while in your hands)
   and `use` (right mouse / left trigger). `slow_fall.gd` is a 10-line example. Drag the script
   into the ItemData's **Ability** slot.
3. **Put it in a level:** drag `items/world_item.tscn` into the level under its **Items** node,
   move it where you want, and drag your `.tres` into its **Item** slot. Where you place it is
   its "home": it goes back there if it falls off the world or is left lying around.

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
- **Run just some:** `run_tests.cmd items` runs only the test files with "items" in their name.
- **Run them after every change** to make sure nothing that used to work has broken.
- **Add a test:** add a `func test_something() -> void:` to a `tests/test_*.gd` file (or make a new one).
  The helpers in `tests/game_test.gd` (`place`, `hold`, `tap`, `run_and_jump`, `expect`, …) do most of the work.
- **Two-player tests** extend `MultiplayerTest` (`tests/multiplayer_test.gd`), which provides `host_main` and `client_main`.
