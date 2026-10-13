# Parkour Friends

Third-person co-op parkour game made with Godot 4.7 (GDScript).

## Running it

1. Double-click `Godot_v4.7.2-stable_win64.exe` (it's in this folder, but it is not committed to Git).
2. In the Project Manager, click **Import**, pick this folder's `project.godot`, then **Import** / **Edit**.
3. Press **F5** (or the ▶ "Run Project" button at the top right) to play.

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD | Left stick |
| Sprint | Shift | Click left stick |
| Jump (hold for higher) | Space | A / Cross |
| Camera | Mouse | Right stick |
| Respawn at checkpoint | R | Back / Select |
| Free the mouse | Esc (click to recapture) | |
| Hide help | F1 | |

## Project layout

Folders are organized by *feature*: each scene (`.tscn`) sits next to its script (`.gd`).

```
game/       main.tscn + main.gd   – starts the game, loads the level, spawns players
player/     player.tscn           – the character
            player.gd             – movement physics (run, sprint, jump)
            player_input.gd       – turns keyboard/gamepad into plain variables
            camera_rig.gd         – third-person orbit camera
levels/     test_course.tscn      – grey-box test course
            level.gd              – base level script (spawn points)
            checkpoint.tscn/.gd   – drop-in respawn checkpoint
ui/         hud.tscn/.gd          – debug overlay (speed, height, controls)
materials/  grid.gdshader + .tres – grey-box materials with a 1 m grid
```

Physics layers (Project Settings → Layer Names → 3D Physics): 1 = world, 2 = players, 3 = triggers.

## Built for multiplayer later

- **Movement never reads the keyboard.** `player.gd` only reads `PlayerInput`'s variables
  (`move_direction`, `jump_held`, …). Later, remote players' `PlayerInput` gets filled from the network.
- **`is_local`** marks the one character this computer controls (camera + input). This becomes
  Godot's "multiplayer authority" check.
- **`main.gd` → `spawn_player(peer_id, is_local)`** already names players by network id, which is
  what Godot's `MultiplayerSpawner` / `MultiplayerSynchronizer` expect.
- **Players are on their own physics layer** and don't collide with each other (or the camera)
  yet — that's a design choice to revisit for co-op (e.g. boosting a friend up a wall).
