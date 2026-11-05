# Making cosmetics (Meshy)

What I need from you: **one GLB file per cosmetic**, dropped into the right folder
under `cosmetics/`. I'll do the Godot side: importing them, fitting each one onto
the blob, making it follow the body as you run, and making trails flow behind you.

Cosmetics don't go through Mixamo. They aren't rigged; I attach each one to a bone
of the blob's skeleton (head, hand, hips, foot), so it moves with the body
automatically.

## The slots

| Slot | Folder | Follows | Examples from your sheets |
|---|---|---|---|
| Head | `cosmetics/head/` | the head | caps, beanies, helmets, hair, sunglasses |
| Hands | `cosmetics/hands/` | both hands | gloves, mittens, watches, bracers, wraps |
| Waist | `cosmetics/waist/` | the hips | belts, sashes, obi |
| Feet | `cosmetics/feet/` | both feet | trainers, boots, flip-flops |
| Trail | `cosmetics/trail/<kind>/` | flows behind you | banners, streamers, scarves, kites |

One item per slot. A combo like "beanie and sunglasses" is fine, but make it as
**one** head item, the way your concept sheet shows it.

## 1. Body items (head, hands, waist, feet)

**Make it with Meshy:**
- Image to 3D works best. Your concept sheets show the items being worn, so
  generate (or crop) an image of **the item on its own**: no mannequin head, arm or
  body, a plain background, and a three-quarter view. If the head or arm is in the
  picture, Meshy builds it into the model and it will poke out of the blob.
- **Hands and feet: make only one side** (either is fine; tell me which). I mirror it for the other, so a pair
  always matches.
- Make gloves, mittens and shoes **a bit chunky**. The blob's hands and feet are
  round mitts, and a slim glove lets the hand poke through.
- A solid model is fine. Hats don't need to be hollow inside; the head hides the
  inside.
- Hair counts as a head item. Hair plus a hat is one head item.

**Before you export:**
- Low poly, around **3,000–8,000 triangles** (Meshy's remesh or polycount
  option). These are small on screen.
- Texture 1024 is plenty.
- Export as **GLB**. It's one file with the textures inside.

Size and position don't matter. I'll scale and place each one onto the blob and
send you a lineup screenshot to check.

## 2. Trail items (the "spot your friend from far away" slot)

The game makes these wave, flap and swing, using a chain that follows you around
like a tail. It reacts to running, jumping, launching off ramps and getting tossed.
That changes one rule:

> **Model trails straight and flat, not flowing.** Your concept art shows them
> mid-wave, which looks great, but if the model is already wavy the game's
> movement gets added on top and it looks crumpled. Ask Meshy for the item
> "laid out straight and flat, not blowing in the wind".

Also:
- Give them **more polygons than body items, around 6,000–12,000**, and spread
  evenly along the length. The game bends the model along its length, so it needs
  enough edges to bend smoothly. Meshy's quad remesh is good for this.
- Make them **long**: about four to eight times as long as they are wide. Exact
  size doesn't matter; I'll scale them up big.
- Texture 1024–2048. Patterns (tartan, stars, scales) are what make them readable
  at a distance.

There are four kinds. Each goes in its own folder, so I know how to hang it:

| Kind | Folder | What to make | How it's worn |
|---|---|---|---|
| Banner | `cosmetics/trail/banner/` | **Just the cloth**: flag, pennant, war banner, tapestry, sashimono. One short edge is the edge that hangs on the pole. | On a pole from a back harness. I make one shared pole and harness. |
| Streamer | `cosmetics/trail/streamer/` | A long creature or ribbon, **straight**: dragon, carp, snake, neon ribbons. The head (or the front end) is the end that attaches. | Ripples out from the top of the back pole. |
| Scarf | `cosmetics/trail/scarf/` | **Two files**: `<name>_neck.glb` (just the wrap around the neck, like a short tube or ring) and `<name>_tail.glb` (one long straight strip with fringe). | The neck wrap sits on the neck and the tail streams out behind. If you only want one tail, I'll use it twice. |
| Kite | `cosmetics/trail/kite/` | The kite itself (diamond, box kite, bird, fish, dragon face), **flat and still**. Any tail ribbon should be straight. | Flies high behind you on an 11 m string from your back (`player/kite.gd`), about 3 m tall so it's seen from afar, turned to face whoever's looking. It stays under ceilings and goes see-through when it's between the camera and you. Its fit says which way its face looks, which end is its top, and its size. |

Glowing bits (like the neon streamer or the cyber visor): Meshy doesn't usually
export glow, so tell me which parts should glow and I'll add it.

## 3. A few don'ts

- **No real logos or brands.** Your space glove sheet has an agency-style patch on
  it. Swap it for a made-up badge before it goes in the game.
- No characters inside the model: no mannequin head, arm, torso or body.
- No poles on banners, and no backpack harness. Those are shared, so every banner
  hangs the same way.

## 4. Handing it over

Name files in lower case with underscores, and they become the item names in the
mall:

```
cosmetics/head/pirate_hat.glb
cosmetics/head/beanie_long_hair.glb
cosmetics/hands/boxing_glove.glb          (one hand only)
cosmetics/waist/champion_belt.glb
cosmetics/feet/high_tops.glb              (one foot only)
cosmetics/trail/banner/pirate_banner.glb
cosmetics/trail/streamer/dragon.glb
cosmetics/trail/scarf/tartan_neck.glb
cosmetics/trail/scarf/tartan_tail.glb
cosmetics/trail/kite/fish_kite.glb
```

**Suggested first batch.** Two per slot is enough to test the whole pipeline
before you make the full sets:
- Head: baseball cap and pirate hat (one simple, one with a wide brim)
- Hands: boxing glove and watch (one covers the hand, one sits on the wrist)
- Waist: champion belt and pirate sash (one stiff, one with hanging cloth)
- Feet: any trainer and one silly one
- Trail: one banner (pirate), one streamer (dragon or carp), one scarf (tartan)

Then I'll:
- import them and fit them onto the blob, and send you the lineup
- make the trails flow, with the scarf, banner and streamer each moving
  differently
- keep the trail big and readable from across the district, which is its job
- make sure friends see your cosmetics online
- later, put them on stalls in the hub mall
