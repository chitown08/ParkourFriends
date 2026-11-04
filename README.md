# Parkour Friends

**Design:** the master design document is the Claude doc
["Parkour Friendslop – Game Design Doc"](https://claude.ai/artifact/FaCnq4frncwnN9L2MgsfSU);
[docs/DESIGN.md](docs/DESIGN.md) has the technical notes. [docs/CHARACTER_GUIDE.md](docs/CHARACTER_GUIDE.md) explains how to make a character in Meshy and Mixamo, and [docs/COSMETICS_GUIDE.md](docs/COSMETICS_GUIDE.md) how to make cosmetics.

Third-person co-op parkour game made with Godot 4.7 (GDScript).

## Running it

1. Double-click **`open_editor.cmd`** to open the Godot editor. (Double-clicking the Godot exe itself runs the
   game instead, because it notices the project in its folder. The exe is not committed to Git.)
2. Press **F5** (or the ▶ "Run Project" button at the top right) to play. Pick a **World** (the Rooftop District playground, or one of the training
   grounds: the Free-Run Line and the Test Course), type **your name** (shown over your head to friends), then **Play Solo** or **Host**.
   Joining players get the host's world. **With Steam running**, Host makes a friends-only Steam game and opens Steam's
   invite window (later: Esc > Invite Friends); friends join by accepting the invite or with "Join Game" in their
   friends list, even with the game closed. Your name starts as your Steam name. Without Steam, Host and Join work by
   address (127.0.0.1 = this computer). In the game, **Esc** has the settings (mouse, fullscreen, volume for
   everything / music / sound effects) and **your outfit** (a hat, gloves, belt, shoes and a trail, or none).
   All of it is remembered for next time. The version number is in the bottom-right corner.
3. **Building the game for friends:** double-click **`build_windows.cmd`**. It makes `buildwindows` (the game
   without developer tools) and runs the built game's self-check (every world loads, outfits, music, Steam).
   The first time, Godot needs its export templates (Editor > Manage Export Templates > Download).
4. In the Rooftop District, bring relics back to the drop-off in the middle of the plaza. The gold rings round each
   relic say how many players it takes to reach: one ring, you can get it alone; four rings, it takes four of you.

## Controls

A short version of this sits in the bottom-left corner while you play (F1 hides it), and a prompt
at the bottom of the screen says what a button would do right now ("E  Toss your friend",
"Space  Climb up"). Both name gamepad buttons instead once you use a gamepad.

| Key | Gamepad | Does |
|---|---|---|
| WASD / mouse | Sticks | Move / look |
| Space (hold: leap) | A | Jump; hold while free-running to ready a leap |
| Shift (hold) | RT (hold) | Free-run: faster (and faster still as your flow builds), auto-parkour, and running as a pack with friends nearby. Without it you just run |
| C or Ctrl | B | Crouch; slide while running; let go of whatever you hold on to |
| E | RB | Do something with a friend: toss them, brace at a wall for a leg-up (or climb onto a braced friend's shoulders), take a hand in a pack (crack the whip); again to stop |
| F (hold: throw) | X (hold: throw) | Items: pick up, drop or hand to the friend you face; hold to throw where the camera points |
| Left click | LT | Use the item in your hands (glider: hold in the air; bat: swing) |
| Q | LB | Rally call: whistle "over here!" A beam of light rises from you for a few seconds, seen through buildings, and friends get an arrow pointing to you |
| R | Back | Back to your checkpoint |
| Esc | Start | Menu: settings, your outfit, leave, quit |
| F11 | | Fullscreen on/off |

**Moves with no button of their own** (the controls above, used in the right place):

| Move | How |
|---|---|
| Grab a ledge, climb up, shimmy | Jump at a wall pushing toward it; Space climbs, left/right shimmies, C lets go |
| Lower yourself over an edge | Crouch-walk off it |
| Wall jump / wall run / wall scramble | Jump next to a wall / run fast alongside a tall one / jump into a too-tall one and keep pushing |
| Slide-jump, ledge leap | Jump during a slide (keeps your speed) / jump while hanging from a narrow sill |
| Drainpipes (yellow), air vents (orange grates), grind rails | Run or jump into a pipe and push to climb / step on a vent / land on a rail |
| Launch roofs (orange) | Run or slide down them fast; a free-run leap at the lip goes furthest |
| Wall ramps and quarter-pipes (orange) | Free-run up them fast and they throw you high: a wall ramp up a building's side (steer for the wall to grab the roof), a quarter-pipe straight up |
| Pipes and tunnels (orange, or glass) | Run through them, or free-run across one with the camera pointing across it and you run up the wall and round: fast enough (full flow in the big road tunnel), over the ceiling. Space jumps off the wall |
| Flow | Keep moving: you build from 10 to 15 m/s; stopping or crashing drains it |
| Pack-running and drafting | Free-run near friends heading the same way: you're pulled along together, and a bigger pack runs faster |
| Hanging chain | Jump or scramble up to a hanging friend's feet; Space climbs everyone |
| Leg-up | Run at a braced friend and jump |
| Crack the whip | Leading a line of friends holding hands: turn hard away from them |
| Catch | Stand at an edge looking out: a friend falling short of it is caught |

**Developer keys** (only when running from the editor; off in the build friends play):

| Key | Gamepad | Does |
|---|---|---|
| G | D-pad down | Call the practice buddy (at an edge, at a wall or while hanging it sets up a catch, a leg-up or a hanging chain) |
| J | | The buddy tosses you |
| H | D-pad up | Ghost runner: the buddy free-runs with you (E then has it take your hand) |
| O | | Try on the next outfit |
| M | | Music on/off |
| F3 | | State, speed, height, network readout |

## Adding a layered song (it swells as your pack grows)

1. In Suno, export the song's **stems** as WAV. Put them in a folder of their own in `audio/stems/`
   (kept out of Git: they're huge).
2. Run (with ffmpeg installed in `%LOCALAPPDATA%ParkourFriendsToolsfmpeg`, from gyan.dev):
   `bash tools/mix_song.sh "audio/stems/My Song" my_song`. It mixes the stems into a few small layer files in
   `audio/music/my_song/`: the groove (drums, bass, keyboard, percussion) always plays; the synth comes in with one
   friend pack-running with you, brass with two, and with three everything. The other instruments are extras: a couple
   play anyway, picked fresh each time the song starts. Alone, the song is a little muffled. Edit the list at the
   top of the script to move instruments between layers.
3. Open the editor once (so Godot imports them). It's in the playlist.

## Project layout

Folders are organized by *feature*: each scene (`.tscn`) sits next to its script (`.gd`).

```
game/       main.tscn + main.gd   – menu → solo/host/join, loads the level, spawns players
            network.gd            – hosting, joining and leaving online games
            reach/reach_map.gd    – the reachability checker: where players can get to, and what it takes
            reach/rules/          – one script per way of getting around (add one for a new move or item)
player/     player.tscn           – the character
            character_model.gd    – the model you see: picks and blends its animations
            player.gd             – shared movement helpers, flow, ledge detection, tossing
            movement_profile.gd   – all the movement numbers; profiles/ has superhuman + human
            player_input.gd       – turns keyboard/gamepad into plain variables
            camera_rig.gd         – third-person orbit camera
            ledge.gd              – data about a grabbable ledge
characters/blob/   blob.fbx + anims/*.fbx – the character and its animations, from Meshy + Mixamo
                   blob_model.tscn       – the model scene the player uses
player/states/                    – one script per movement "mode" (state machine):
            player_state.gd       – base class every state extends
            ground.gd, air.gd     – running; jumping/falling (+ starts ledge grabs)
            hang.gd, climb.gd     – hanging/shimmying; pulling up / vaulting
            vault.gd              – the flow vault: free-run skimming over something low
            pipe_climb.gd         – climbing a drainpipe (levels/drainpipe.gd)
            chain_hang.gd         – hanging from a friend's feet (a hanging chain)
            chain_climb.gd        – climbing up a hanging chain onto the top
            brace.gd              – bracing at a wall (or on a friend's shoulders) for a leg-up
            leg_up.gd             – stepping up a leg-up stack and launching up the wall
            linked.gd             – holding a friend's hand in a line (crack the whip)
            whip.gd               – cracking the whip, as the leader: pivoting
            whipped.gd            – swinging round with the line, then let go (or flung)
            catch.gd              – holding a friend you caught at an edge
            caught.gd             – caught by a friend at an edge: hanging from their hands
            crouch.gd, slide.gd   – crouch-walking; sliding (slopes speed you up)
            wall_run.gd           – running along walls (wall jumps live in air.gd)
            wall_scramble.gd      – running up a too-tall wall
            grind.gd              – grinding a rail
            glide.gd              – gliding (started by the glider item, items/abilities/glide.gd)
levels/     rooftop_district.tscn – a 5 x 5 block grey-box district with two crossing avenues, a launch plaza and five relics (default
                                    world; regenerate with tools/gen_district.gd, see the top of that file)
            free_run_line.tscn    – straight test course with every move in order (regenerate with
                                    tools/gen_free_run_line.sh)
            test_course.tscn      – grey-box playground for each move (the tests use it)
            level.gd              – base level script (spawn points)
            checkpoint.tscn/.gd   – drop-in respawn checkpoint
            drop_off.tscn/.gd     – where relics are delivered (team-shared count in game/main.gd)
            grind_rail.tscn/.gd   – a grind rail: straight (set end_point) or any shape (give it a Curve3D)
            ramp.gd               – a launch roof: slide down it fast and its lip launches you
            drainpipe.gd          – a yellow drainpipe up a wall (climb it: PipeClimb)
            air_vent.gd           – an orange pavement vent that blows you up to a roof
items/      world_item.tscn/.gd   – a physical item in the world (the host decides who holds it)
            item_data.gd          – what kind of item it is: name, looks, weight, throw speed, ability
            item_ability.gd       – base class for what an item does while in your hands
            data/                 – one .tres per kind of item (relic, glider, bat, crate, test_balloon, …)
            models/               – item models (relic_gem.tscn)
            abilities/            – ability scripts (glide.gd, bat_swing.gd, slow_fall.gd, …)
player/     item_carrier.gd       – what you hold (one thing, in your hands) and the item buttons
ui/         hud.tscn/.gd          – on screen while playing: controls card, button prompt, messages, relics, items (F3: debug readout)
            control_names.gd      – what each control is called (keyboard or gamepad, whichever you last used)
            main_menu.tscn/.gd    – start menu
materials/  grid.gdshader + .tres – grey-box materials with a 1 m grid (colour says what for: red grid_vault = vault it, yellow grid_climb = climb it, orange grid_ramp = launch off it)
audio/music/                      – background music (made by Graham in Suno): drop .mp3 or .ogg files here and open the
                                    editor once; they're shuffled into the playlist (a world starts with its Level.music)
            rooftop_test/         – a layered song (see below): base.ogg, pack1.ogg, pack2.ogg, extra-*.ogg
audio/stems/                      – Suno stem WAVs, kept on your computer only (not in Git: too big)
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
   climbing while holding it), **Pick Up On Touch**, **Hovers At Home** and
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
  run by this computer with no camera or controls, for practising tosses alone. `ghost_run` makes it a ghost
  runner (`ghost_of`, `_steer_ghost` in `player.gd`): it free-runs whenever you do, roughly your way.
- **Pack-running** (`_run_with_pack` in `free_run.gd`): each player sends `sync_free_run_velocity` (zero unless
  free-running; at their own pace, without the pack's easing, or two friends would keep speeding each other up), so
  everyone's computer can see who is free-running near them and nudge their own heading and pace.
- **Each player gets their own colour**, chosen by the host and sent to everyone by the `HostSync` node
  (the one synchronizer the host controls, rather than the character's owner).
- **Not done yet:** playing over the internet (needs port forwarding, a relay, or Steam).
## Automated tests

`tests/` holds gameplay tests that play the game in code (no window) and check the results:
speeds, jump height, ledge grabs, slides, wall moves, tossing, checkpoints, menus, and multiplayer (a host and a joiner run
side by side in one program and must see each other move).

- **Run them:** double-click `run_tests.cmd`, or run it from a terminal. It prints PASS/FAIL for each test.
  The whole suite takes about half a minute: the game runs as fast as the computer allows
  (`--fixed-fps 60` makes every frame count as 1/60 s, however quickly it really went), so a
  test's "seconds" are game seconds, not real ones.
- **Run just some:** `run_tests.cmd items` runs only the test files with "items" in their name.
- **Run them after every change** to make sure nothing that used to work has broken.
- **Add a test:** add a `func test_something() -> void:` to a `tests/test_*.gd` file (or make a new one).
  The helpers in `tests/game_test.gd` (`place`, `hold`, `tap`, `run_and_jump`, `expect`, …) do most of the work.
- **Two-player tests** extend `MultiplayerTest` (`tests/multiplayer_test.gd`), which provides `host_main` and `client_main`.
