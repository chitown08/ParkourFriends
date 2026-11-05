# Making the character (Meshy)

What I need from you: **one rigged character file plus one file per animation**.
Drop them anywhere under `characters/blob/` and tell me. I do the Godot side:
importing, naming, wiring each animation to the right movement, and recolouring
each player.

## 1. The model

**Make it:**
- Generate it with Text to 3D, or Image to 3D from your concept image.
- Ask for a **T-pose or A-pose**: arms out from the body, legs a little apart. The
  auto-rigger needs to see the arms and legs. Short arms are fine; arms melted into
  the body aren't.
- Keep it **bald and plain**: no hat, hair, scarf, flag or backpack. Those are
  separate cosmetics, so they must not be part of the body.
- Make it **one main body colour, ideally white or light grey**. The game tints the
  body per player, and a light base tints cleanly. Dark details like eyes are fine.
- Go low-poly (remesh to around **5,000–15,000 triangles**), texture 1024 or 2048.

**Rig it in Meshy** (no fingers is fine) and download the rigged character as **FBX**.

## 2. Animations

From the same rigged character, add animations from Meshy's library and download
each as **FBX**. Pick **in place** whenever it's offered (if a move can't be, it's
fine: the game takes the travel out).

The list of what the game uses, and what we still need, is
**[ANIMATION_LIST.md](ANIMATION_LIST.md)**. Name each file after the move, as in that
list, or leave Meshy's name and I'll rename it.

**Other sources work too.** Every animation is retargeted onto Godot's standard
humanoid skeleton when it's imported, so animations made on other rigs play on the
character: Mixamo, a store pack, or motion capture from video. Each rig needs a
bone map once:
- `characters/meshy_bone_map.tres`: Meshy's rig.
- `characters/mixamo_bone_map.tres`: Mixamo's rig.

A new rig gets its own map; the bone names come from `tools/inspect_fbx.gd`.

## 3. How it's set up (for me, next time)

- `characters/blob/chubby.fbx` is the character, and `blob_model.tscn` shows it.
- `characters/blob/anims/<move>.fbx` holds one animation each. Its `.import`:
  - retargets its skeleton (`"nodes"` → `"PATH:<skeleton>"` →
    `"retarget/bone_map"`);
  - saves its one animation to `<move>.res`, with the loop mode.

  Meshy's skeleton path is `Armature/Skeleton3D`, its animation is named
  `Armature|Armature|Armature|Armature|<clip>|baselayer`, and the rig's own
  rotation track is stripped when loading. Mixamo's skeleton path is `Skeleton3D`
  and its animation is `mixamo_com`.
- **When re-importing an animation**, if Godot complains `Unrecognized UID`, delete
  its `.res` first and set `save_to_file/path` to the `res://` path.
- **Old Mixamo files** have no proper rest pose, so their hips come out 2.98 times
  too high. `CharacterModel` puts that right as they load (`MIXAMO_HIPS_HIGH`).
- **Clips the game doesn't use yet** live in `characters/blob/spare/` (walking, a
  run-jump-roll).
- **Checking it:**
  - `tools/pose_sheet.gd` renders the character in a grid of animations.
  - `tools/cosmetics_lineup.gd` renders it wearing every cosmetic.
- **Cosmetics** (`cosmetics/fits.cfg`) are fitted on this body at rest (its T-pose), in its
  own space: feet at 0, facing +Z, left hand at +X. Its measurements are at the top of the
  file; `tools/measure_cosmetics.gd` measures the body and every model, to start a fit from.

If Meshy gives you trouble, send a screenshot and we'll sort it out.
