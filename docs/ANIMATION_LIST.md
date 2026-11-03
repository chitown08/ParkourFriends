# Animation list

Every animation the game uses, what it's for, and whether we have it yet. Work through it at your
own pace: anything missing plays a stand-in until its file arrives.

**Status:** ✅ have it · 🟡 stand-in (something else plays for now) · ⬜ new (nothing plays yet;
the game carries on without it)

## How the files work

- One animation per file, named exactly as in the tables (e.g. `vault.fbx`), in
  `characters/blob/anims/`. Godot pulls the animation out when it imports the file.
- **Variants** — a move can have a set to pick from, so it doesn't look the same every time:
  the plain name plus a dash and anything, e.g. `vault.fbx`, `vault-kong.fbx`, `vault-roll.fbx`.
  Each time you start the move one of the set is picked at random (friends see the same one).
  Adding a variant is just adding a file: nothing else to change.
- **In place**: animations should stay on the spot (the game moves you). If one can't be made in
  place (a vault or a roll that travels), it's fine: the game takes the travel out.
- **Looping**: the ones marked 🔁 loop (idle, running, hanging...); the rest play once.

**Switching to Meshy for rigging and animations** (from Mixamo): one website instead of two. Meshy's
skeleton names its bones differently from Mixamo's (e.g. `Hips` rather than `mixamorig_Hips`), and
the game looks some up by name: the hips (to hold travelling moves in place) and the bones
cosmetics hang from (head, hands, hips, feet, neck, spine). When the first Meshy-rigged character
arrives I'll switch those names over and re-fit the cosmetics (`cosmetics/fits.cfg`). Export each
animation on the same rigged character, so they all share one skeleton.

## On the move

| File | For | Status | Variant ideas |
|---|---|---|---|
| `idle` 🔁 | standing | ✅ | `idle-look` (looking about), `idle-stretch` |
| `run` 🔁 | running (without free-run) | ✅ | |
| `sprint` 🔁 | free-running at speed | ✅ | `sprint-lean` (arms back, leaning in) |
| `jump` | taking off | ✅ | `jump-tuck` |
| `fall` 🔁 | in the air, coming down | ✅ | `fall-flail` |
| `leap` | a big free-run leap, on the way up | ⬜ | `leap-frontflip`, `leap-twist`, `leap-dive` |
| `land` | landing from a big drop | ✅ | `land-roll` (parkour roll), `land-stumble`, `land-hero` (one knee down) |
| `slide` 🔁 | sliding | ✅ | `slide-baseball` |
| `crouch_idle` 🔁 / `crouch_walk` 🔁 | crouching | ✅ | |

## Over, up and along things

| File | For | Status | Variant ideas |
|---|---|---|---|
| `vault` | the flow vault over low things | ✅ | `vault-kong` (both hands, dive over), `vault-speed` (one hand, side on), `vault-roll` (roll across the top), `vault-flip`, `vault-lazy` (swing the legs over) |
| `hang` 🔁 | hanging from a ledge | ✅ | |
| `shimmy` 🔁 | moving along a ledge while hanging | 🟡 `hang` | |
| `climb_up` | pulling up onto a ledge | ✅ | `climb_up-quick` |
| `wall_scramble` 🔁 | running up a too-tall wall | ✅ | |
| `wall_run_left` 🔁 / `wall_run_right` 🔁 | wall running | ✅ | |
| `pipe_climb` 🔁 | climbing a drainpipe | 🟡 `wall_scramble` | |
| `grind` 🔁 | riding a rail, side on | ✅ | `grind-crouch`, `grind-arms_out` |

## With friends

| File | For | Status | Variant ideas |
|---|---|---|---|
| `toss` | boosting a friend with both hands | ✅ | |
| `wave` | the rally call: waving "over here!" | ⬜ | `wave-whistle` (fingers in mouth) |
| `tossed` | flying from a toss | ✅ | `tossed-spin`, `tossed-starfish` |
| `brace` 🔁 | back to a wall, hands cupped for a leg-up | 🟡 `crouch_idle` | |
| `leg_up` | stepping into cupped hands and being launched | 🟡 `wall_scramble` | |
| `chain_hang` 🔁 | hanging from a friend's feet | 🟡 `hang` | |
| `chain_climb` 🔁 | climbing up friends | 🟡 `wall_scramble` | |
| `linked` 🔁 | running holding a friend's hand (one arm out) | 🟡 `run` | |
| `whip` | the leader planting and pivoting | 🟡 `run` | |
| `whipped` | swinging round on the end of the line | 🟡 `run` | `whipped-flail` |
| `catch` 🔁 | kneeling at an edge, holding someone's hands below | 🟡 `crouch_idle` | |
| `caught` 🔁 | dangling from a friend's hands | 🟡 `hang` | |

## Items

| File | For | Status | Variant ideas |
|---|---|---|---|
| `carry` 🔁 | holding a bulky item | ✅ | |
| `throw` | throwing an item | ✅ | `throw-underarm` |
| `swing` | swinging the bat | ✅ | |
| `glide` 🔁 | holding the glider | ✅ | |

## Nice to have later

These need a little wiring as well as the file (the game doesn't yet tell these moments apart).

| File | For |
|---|---|
| `wall_jump` | kicking off a wall |
| `ledge_leap` | leaping up from a hang to the next ledge |
| `pipe_slide` | sliding down a drainpipe |
| `skid` | stopping hard from a run |
| `cheer` | delivering a relic at the drop-off (`cheer-jump`, `cheer-fist_pump`...) |
| `emote-*` | emotes, one day |

The 🟡 and ⬜ rows in the tables above only need their file: the game already plays them when
they exist (and the stand-in until then).
