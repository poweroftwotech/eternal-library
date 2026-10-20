# Phase 3 approval brief: props and persistence

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-20 (Q1–Q9 as recommended); step 1 in progress** ·
Technical detail: [phase-3-design.md](phase-3-design.md)

This page is what you're approving. It says what you'll be able to do when
phase 3 is finished, the order it gets built in, and nine choices that need
your answer. Nothing has been coded yet.

## What phase 3 adds, in one paragraph

Today the Reading Room and its galleries are scenery. Nothing moves, and
nothing is remembered between runs. After phase 3:

- objects can be pushed, knocked over and broken;
- books can be pulled off the shelves, and rare **lore books** can be taken
  and read;
- the game **remembers all of it** after you quit and start again;
- a test button lets years pass: lamps nobody tends slowly go out, and the
  ones you looked after stay lit.

## The finish line (from the roadmap)

> Knock over a vase, pull a lore book and take it, quit; in a new process
> both stay changed. Advancing the world clock darkens untouched lamps only.

"In a new process" means the game is fully closed and started again, not
just reloaded. Every save check is run that way.

## The four steps

You review each step in the game before the next one starts.

| Step | What you can try when it's done | How it's checked |
|---|---|---|
| **1. A vase you can knock over** | Two tall vases stand either side of the iwan. Walk into one or press **E**: it rocks, falls, and smashes if it falls hard. Pots, books and inkwells on the reading tables can be pushed off too. Nothing is saved yet. | An automated test of push, fall, break and "settles and goes still". The real player pushes a vase over. Screenshots before and after. Frame time with all props at rest. |
| **2. It stays knocked over** | Break a vase and quit. Start the game: you're back in the same room and spot, among the shards. The Esc menu gets **Forget this library** to start the world over. | Save in one run, then check in a fresh run that every piece is where it was. |
| **3. Pull a lore book and take it** | Look at a shelf and one book is highlighted. **E** pulls it half out. Ordinary books can then be pushed onto the floor. A gilt-spined lore book can be **taken**, and the **J** notes gain a **Satchel** where you can read it. R01 hides two: one on the ground floor, one up on the gallery. | The same two-run check, now including the book. A check that adding a lore book doesn't shuffle the other books. |
| **4. Years pass** | Light or douse a lantern under the gallery. The Esc menu's **Let ten years pass** ages the world: untouched lamps flicker, then go dark. Yours stays lit. Quit and restart: still the same. | A third run jumps 40 years and checks that only untouched lamps changed. It runs twice to prove the result is the same every time. |

Step 3 meets the first half of the finish line. Step 4 meets all of it. An
optional step 5 (drop items back into the world, breakable table pots) comes
only if you want it after reviewing step 4.

## Not in phase 3

- Picking things up and carrying or throwing them. You push, and you take
  items, but you don't hold them.
- Quick slots. There's no quick-slot code in the prototype to build on.
- Saving the camp's gatherable plants.
- Aging anything other than lamps (crumbling shelves, spreading growth).
- Streaming rooms in and out. That's phase 4.

## Two things found while planning

- **A small existing bug:** the player is on the physics layer reserved for
  props. Step 1 fixes it. Nothing visible changes.
- **No quick slots exist** in the camp code, despite the old plan's
  wording. The inventory is three ingredient counters. Phase 3 turns it into
  a real satchel, so the camp's ingredients and the lore books live in one
  place.

## Decisions for you

Each choice has my recommendation first. Answering "go with your
recommendations" is fine.

| # | Question | Recommended | Alternative | What changes |
|---|---|---|---|---|
| **Q1** | When a room's random seed changes, should its saved changes still apply? | **No.** Changes belong to that exact version of the room. Reseed a gallery and you get a fresh one; go back to the old seed and your changes are there. | Hand-placed props (like the two vases) keep their changes even if R01's seed changes. | The alternative needs two id rules instead of one. It matters only while developing, because in the real game a world's seed never changes. |
| **Q2** | How does the player handle props? | **Push (walk into it or press E) and Take (for items).** No carrying. | A grab-and-carry with E held, plus throwing. | Carrying is a bigger feature (holding, rotating, throwing). It's better as its own step later. |
| **Q3** | What happens to the shards of a broken vase? | **They stay** where they land, and they're saved, so you see the mess when you come back. | They vanish after a while, and only "this vase is broken" is saved. | Staying feels right for "the world remembers". It's capped, so it can't pile up forever. |
| **Q4** | Where does the game start after you quit? | **Where you left off:** the same room, position and view. | Always at the camp, with the world's changes kept. | Resuming makes the save test (and play) natural. The command line can still choose a room. |
| **Q5** | Are the satchel's camp ingredients saved even though the camp's plants regrow? | **Yes.** Save the satchel, and let the camp regrow for now. | Also save which camp plants were picked. | The camp is old prototype code, due to be rebuilt later. The "regrow" exploit doesn't matter yet. |
| **Q6** | Can the small table pots break? | **Not in phase 3.** They can be pushed off, but they need their own shard models. | Make small shards now as well. | That's one more Blender model and test. It's in the optional step 5. |
| **Q7** | Save file format? | **A readable text file (JSON).** You can open it, and a broken save is easy to diagnose. | Godot's binary format. | Binary is a little smaller and faster. Not worth it at this size. |
| **Q8** | Taking a lore book: one press or two? | **Two:** the first E pulls it out, the second takes it. That matches the finish line's "pull … and take". | One press takes it straight off the shelf. | Two presses also make pulling ordinary books a thing you can do. |
| **Q9** | How does time pass? | **Only with a test button** (and a command-line option) in phase 3. | Time passes as you play. | Real time passing needs game-design decisions (how fast, what triggers it) that belong to a later phase. |

**Also needed from you:** the two lore books need short texts. I'll draft
two placeholder passages in the game's voice for you to replace or approve,
unless you'd rather write them.

## How to approve

Reply with "approved" (or "approved, but Q… = …"). Step 1 then starts, and
you'll be asked to look at it in the game before step 2 begins.
