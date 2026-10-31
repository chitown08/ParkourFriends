# Making the character (Meshy + Mixamo)

What I need from you: **one character file plus one file per animation**, dropped
into `characters/blob/`. I'll do the Godot side: importing, wiring each animation to
the right movement, recolouring each player, and attaching the back flag later.

## 1. The model (Meshy)

**Make it:**
- Generate it with Text to 3D, or Image to 3D if you use your concept image.
- Ask for a **T-pose or A-pose**: arms out from the body, legs a little apart.
  Mixamo's auto-rigger needs to see the arms and legs, so short arms are fine but
  arms melted into the body aren't.
- Keep it **bald and plain**: no hat, hair, scarf, flag or backpack. Those become
  separate cosmetics later, so they must not be part of the body.
- Make it **one main body colour, ideally white or light grey**. The game tints the
  body per player (that's how friends get different colours), and a light base
  tints cleanly. Dark details like eyes or shoes are fine.

**Before you export:**
- Use Meshy's remesh or polycount option to go low-poly, around **5,000–15,000
  triangles**. That suits the look, and with lots of players on screen it matters.
- Keep the texture at 1024 or 2048. No need for more.
- Export as **FBX** (best for uploading to Mixamo) or **GLB**.

Size doesn't matter: I'll scale it to fit the 1.8 m body.

## 2. Rigging and animations (Mixamo, free with an Adobe account)

**Rig it:**
1. Go to mixamo.com, choose **Upload Character** and give it the FBX.
2. Place the markers (chin, wrists, elbows, knees, groin). Set **Skeleton LOD** to
   "Standard Skeleton (65)", or "No fingers" if the hands are mitts.
3. If the auto-rig looks broken (the arm bends in the wrong place), the pose is
   usually the cause. Go back to Meshy for a clearer T-pose.

**Download the character once:**
- Format **FBX Binary**, **With Skin**, pose T-pose.
- Save it as `blob.fbx`.

**Then download each animation:**
- Format **FBX Binary**, **Without Skin** (smaller files; they reuse the
  character's skeleton), 30 frames per second.
- Tick **In Place** whenever the option appears. This one is important: the game
  moves the body itself, so animations that walk off on their own will slide.

## 3. Animation list

Exact Mixamo names change, so search with the words below and pick whatever looks
good. Save each one with the file name in the first column. These are the moves the
game has today.

**Must have (top priority)**

| File name | What it's for | Search Mixamo for |
|---|---|---|
| `idle` | standing | "idle" (something bouncy suits a blob) |
| `run` | normal running | "running" (In Place) |
| `sprint` | full flow, top speed | "fast run" / "sprint" (In Place) |
| `jump` | taking off | "jump" (the take-off part) |
| `fall` | in the air, coming down | "falling idle" |
| `land` | landing from a big drop | "falling to landing" / "hard landing" |
| `slide` | sliding | "running slide" / "baseball slide" |
| `hang` | hanging from a ledge | "hanging idle" / "braced hang" |
| `climb_up` | pulling up onto a ledge | "climbing up" / "braced hang to crouch" / "freehang climb" |

**Nice to have**

| File name | What it's for | Search Mixamo for |
|---|---|---|
| `vault` | hopping over a low wall | "vault" / "jump over" |
| `crouch_idle` / `crouch_walk` | crouching | "crouch idle" / "crouched walking" |
| `wall_run` | wall run (I lean the body for the wall side, so one is enough) | Mixamo has no true wall run; a "running" variant works |
| `wall_scramble` | scrambling up a too-tall wall | "climbing" / "wall climb" |
| `grind` | riding a rail, side-on like a skateboarder | "surfing" / "skateboarding" idle, or a balancing pose |
| `glide` | holding the glider | "hanging" (arms up) / "falling" variants |
| `throw` | throwing an item | "throw" |
| `swing` | bat swing | "baseball hit" / "sword slash" |
| `toss` | boosting a friend with both hands | "lifting" / "pushing" / "throw" with two hands |
| `carry` | holding a bulky item | "carrying" / "box idle" |
| `tossed` | being flung through the air | "flip" / "front flip" (not In Place is OK for this one) |

Start with the must-haves. Once the character runs and jumps, the rest is easy to
add, and anything missing just falls back to a similar animation.

## 4. Handing it over

```
characters/blob/blob.fbx
characters/blob/anims/idle.fbx
characters/blob/anims/run.fbx
...
```

Drop the files in and tell me. I'll do the rest:
- import them, set up the Godot settings and keep the animations looping
- swap out the bean, keeping the same collision body, so nothing about movement
  changes
- blend between animations, e.g. run into sprint as flow builds, jump into fall
- keep the squash and stretch and leaning, and colour each player
- make sure friends see your animations online too

If Mixamo or Meshy gives you trouble, send a screenshot and we'll sort it out.
