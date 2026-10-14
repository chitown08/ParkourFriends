# Parkour Friends: Design Document

A living document: the game we're aiming for, the rules we design by, and the
open questions. Edit it freely. When something here changes, change it here first.

---

## 1. The game in one paragraph

A third-person co-op parkour game set in a sky of **floating islands**. You spawn in
a vertical **city hub**, run and climb around, meet up with your friends, and head out
to find harder and harder things to reach: summits, hidden collectibles, whole themed
islands. You can do a lot alone, but friends make it better. You can **toss each other**
to places nobody could reach solo, and you each carry **different gear**, so a team
covers more than any one player.

## 2. Design pillars

When a decision is unclear, these break the tie.

1. **Moving feels great.** Running, climbing and flying through the world is the core
   joy. Everything else supports it.
2. **Together is better, not required.** Co-op opens shortcuts, bonus areas and
   faster routes. Solo players can still finish the core game. Some **bonus** content
   needs friends, but never the main path.
3. **Curiosity is rewarded.** If you can see somewhere, there's probably a way up, and
   usually something there when you arrive.
4. **No item makes a move pointless.** Every item has a clear job and clear limits.
   Ledge grabs, wall runs and tosses must stay useful no matter what you're carrying.
5. **Small first, then grow.** Build a small slice, play it with friends, learn, then
   expand. Grey boxes until the fun is proven.

## 3. The world

### Floating islands
- **City hub ("Old Town")**: where everyone spawns. Rooftops, alleys, tall buildings,
  Crackdown-style vertical climbing. Teaches the moves, holds the first items, and is
  where friends meet up.
- **Themed islands** float around the hub, each leaning on different moves and items:
  - **Ancient Greece**: columns, temples, broken stairways, an acropolis to climb.
  - **Sci-fi**: platforms, pipes, antennas, moving parts.
  - *More later.*
- **Getting between islands is a challenge in itself**: glide across, get tossed up a
  broken bridge pillar or batted over a gap, or swing on a grapple. (Tosses are mostly
  *upward*, so they get you onto high things; crossing wide gaps is the bat's job.)
- **Bonus islands for bigger groups**: some can only be reached with more players,
  e.g. a gate or lift needing several pressure
  plates held at once. Always bonus, never required (pillar 2). The practice buddy
  doesn't count.

### Collectibles and objectives
- **Relics** *(working name)*: collectibles scattered around the islands in three tiers:
  - **Easy**: street level or a short climb. Teaches you to look around.
  - **Medium**: rooftops and side paths. Uses the full move set.
  - **Hard**: summits, hidden spots, or places that need a friend or a specific item.
- **Shared by the team**: if anyone in the group collects a relic, it counts for
  everyone. Friendlier, no arguments.
- **Landmarks are goals**: tall things you can see from far away (a clock tower, a
  temple roof) with a reward at the top.

## 4. Movement (what's built)

| Move | How | Notes |
|---|---|---|
**The game is deliberately over the top**: you start superhuman (Crackdown-style) and get more
so as the team finds relics.

| Move | How | Notes (superhuman profile) |
|---|---|---|
| Run + flow | WASD | 10 m/s, building to 15 m/s over 3 s of uninterrupted movement ("flow"); stopping, letting go or crashing drains it |
| Jump | Space (hold = higher) | ~3 m full jump, coyote time + jump buffering |
| Ledge grab, hang, shimmy, climb | Jump at a wall while pushing toward it | Grabs up to ~2.6 m above your feet; low ledges are vaulted |
| Crouch / slide | C (hold) | Slides speed up downhill; slide-jumps keep their speed |
| Wall jump | Space in the air next to a wall | Not the same wall twice before landing |
| Wall run | Run fast, jump alongside a tall wall | Up to 1.6 s, slowly sinking |
| Toss a friend | E | ~8 m up. See section 5 |

All the feel numbers live in **movement profiles**: `player/profiles/superhuman.tres` (the
default) and `human.tres` (realistic numbers, for comparison and for the move tests). Switch
between them in the pause menu.

### Agility levels (built)
The team's relic count sets everyone's **agility level**: level 2 at 2 relics, 3 at 5, 4 at 8,
5 at 11. Each level adds +12% jump height and +5% running speed (numbers in the profiles).
Later worlds can be designed around higher agility levels.

## 5. Co-op

### Tossing (built)
- **E / right bumper** launches the nearest friend within 2 m (not behind you) up and
  toward where your camera faces.
- **Mid-air toss = co-op double jump**: tossing while airborne gives you a small hop too.
- **Limits**: once per air time each player can toss once and be tossed once. Landing,
  grabbing a ledge, wall running or wall jumping refreshes both. (`limit_tosses_per_air`
  switches this off if we want to try unlimited juggling.)
- **Practice buddy**: in solo games, a grey stand-in you can toss (E) or get tossed by (Q).

### Co-op ideas (not built yet)
- **Hold-to-aim toss**: hold E to aim with more precision before releasing.
- **Bat / golf club**: launch friends farther but flatter (see Items).
- **Stand on a friend's head / boost up**: needs players to collide with each other.
- **Pressure plates and multi-person gates**: for bonus areas.
- **Finding each other**: markers above friends' heads, a "regroup" option, maybe a compass.

## 6. Items

### Carrying rules (inspired by The Big Walk)
- You hold **one item in your hands**.
- A **backpack** and a **belt** each give you **one extra slot**. They're found in the
  world, not given at the start.
- No endless inventory: **what you carry, and who in the team carries what, is a choice.**
- Items can be **dropped** and **picked up**, including the ones your friends drop.

### Item list

| Item | What it does | Built on | Limits so it doesn't break other moves |
|---|---|---|---|
| **Glider / parachute** | Slow descent, long distances | New state | Only goes *down and across*. Height must come from climbing or a friend's toss. |
| **Baseball bat / golf club** | Launch a friend **farther but flatter** than a toss | The toss | Less height than a toss, so it doesn't replace it. |
| **Pogo stick** | Jump much **higher but shorter** | The jump | Little forward distance; probably awkward on narrow beams. |
| **Running shoes** | **Faster running** | Run speed | Little else. Choosing them means not carrying something else. |
| **Grappling hook** | **Swinging** from anchor points; climbing the rope is possible but slow and clumsy | New state with rope physics | Only hooks onto placed **anchor points**. Swinging, not "pull me up there". |
| **Suction cups** | Slow wall climbing | New state | Slow, uses a stamina bar, only on certain surfaces. |

**Planned build order:** glider (needed to reach islands) → bat, pogo, shoes (cheap,
since they modify existing moves) → grapple (the biggest single feature) → suction cups.

**Natural combos we want to work:** bat a friend off a cliff, they glide to the next
island. Toss a friend high, they deploy the glider. Grapple-swing to a ledge, then toss
the next friend up.

## 7. Multiplayer and tech

- **Host and join**, up to 4 players. Each player's computer runs their own character and
  shares its position/state (smooth and responsive, fine for co-op).
- **The host owns world state** (relics collected, items lying in the world, gates opened)
  and shares it, so everyone agrees on what's been picked up.
- **Internet play** is still to come: start with port forwarding (free), consider friend
  codes / a relay or Steam later.
- **Automated tests** cover moves, menus, tossing and multiplayer. New features come with tests.

## 8. Roadmap

1. **First slice (in progress):** grey-box the city hub and the ancient Greece island (done), with
   spawn, landmarks, a handful of relics, and the glider to find. See
   [first_slice_map.svg](first_slice_map.svg).
   - Glider item and the item-carrying system (one hand slot)
   - ~~Relics (team-shared) and a simple counter on screen~~ (done)
2. **Play it with friends** (needs internet play) and adjust.
3. **More items**: bat, pogo, shoes; backpack/belt slots.
4. **Saving** progress.
5. **Grappling hook.**
6. **Game feel pass**: floatiness, camera follow, sounds, small effects.
7. **More islands**, including the first bonus island for bigger groups.

## 9. Open questions

- **Saving**: is progress per player, per group, or per world (like a shared save file the host keeps)?
- **Running shoes**: hand slot, or a separate "worn" slot? What exactly can a backpack vs. a belt hold?
- **Item respawning**: if an item falls off an island, does it come back?
- **Falling off islands**: respawn at the last checkpoint? Is there a "net" island below?
- **Relic name and look**: relics, shards, stars, coins...?
- **Double jump**: Graham has ideas to brainstorm (tossing already acts as a co-op double jump).
- **Toss juggling**: keep the once-per-air limit, or try unlimited after playtesting?
- **How many players** should the bonus islands need: 3? 4? Scalable?
- **Toss chains don't exist (yet)**: with the once-per-air-time rule, everyone in the air
  has already been tossed, so 3 players can't get higher than 2. Bonus areas for bigger
  groups need another mechanic (pressure plates holding a lift up? a "human ladder"?),
  or we loosen the toss rule. The Sky Garden is a placeholder until this is decided.

## 10. Ideas parking lot

Good ideas not scheduled yet: hold-to-aim toss · players colliding / standing on heads
· regroup markers · emotes · photo mode · time-trial routes between landmarks ·
cosmetic unlocks from relics · Steam friends and invites.
