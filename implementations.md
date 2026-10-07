# Puzzle Combat Refactor — Prepared Matches, Tap-to-Explode, and Special Gems

I want to refactor the current puzzle-combat prototype in **two separate phases**.

The existing game already has:

* A grid-based puzzle board.
* Falling pieces composed of two blocks.
* Three block colors with basic gameplay meanings:

  * **Red** = damage
  * **Yellow** = energy
  * **Blue** = guard
* Match detection for 3+ orthogonally connected blocks of the same color.
* A visual highlight/pulse that is already shown briefly when a valid group is detected, immediately before the matched blocks currently disappear.
* Gravity/cascade behavior after blocks are removed.

Do **not** rewrite the existing architecture unnecessarily. First inspect the current implementation and identify the existing systems responsible for:

* board state
* piece placement
* match/group detection
* highlighting
* block removal
* gravity
* cascades
* damage/energy/guard effects

The implementation should preserve the current behavior wherever it is not explicitly changed below.

---

# PHASE 1 — Prepared Groups + Tap to Explode

## Goal

Change the current behavior from:

```text
3+ matching blocks detected
→ highlight briefly
→ blocks automatically disappear
→ gravity
→ cascade
```

to:

```text
3+ matching blocks detected
→ group becomes PREPARED
→ group remains highlighted/pulsing
→ player can continue playing
→ player taps the prepared group
→ group explodes
→ gameplay effect is resolved
→ blocks are removed
→ gravity
→ new groups are detected
```

The important change is that **match detection must no longer automatically destroy the matched blocks**.

The existing highlight implementation should be reused and adapted. It already provides the visual language for a detected group; instead of being a short preview before automatic destruction, it should represent a group that is currently ready to be detonated.

## Prepared groups

A valid group of 3 or more same-color blocks should become a persistent **prepared group**.

A prepared group should:

* remain highlighted/pulsing until resolved;
* remain part of the board;
* prevent its blocks from being removed automatically;
* be directly tappable;
* be identifiable independently from other prepared groups.

There may be multiple prepared groups on the board at the same time.

For example:

```text
RRR       BBB
RR        B
```

could result in:

```text
RED group: 5 blocks — PREPARED
BLUE group: 4 blocks — PREPARED
```

The player can choose which group to detonate first.

Do not introduce a global "Resolve" button.

The interaction should be direct:

> **Tap a prepared group to explode it.**

The tap should work when the player taps any block in that prepared group, with a reasonably generous touch area if necessary.

## Important interaction rule

Do not create a modal "Hold or Resolve?" interaction.

The player simply does nothing if they want to keep the group prepared.

"Waiting" is passive. The player does not need a separate hold action.

This should preserve a fluid mobile-game interaction:

```text
place piece
→ group becomes prepared
→ keep playing / place another piece
→ tap group when desired
→ explosion
```

The player should therefore be able to intentionally build a larger match before detonating it.

For example:

```text
RRR
```

becomes prepared.

The player can place another red block:

```text
RRR
  R
```

and the same prepared group should now represent 4 connected red blocks.

Another placement could produce:

```text
RRR
RR
```

and the prepared group becomes 5 blocks.

The match should not be destroyed simply because it reached 3.

## Group identity

Avoid treating a match as only a temporary list that exists for one frame.

Prepared groups need a persistent identity/state while they remain on the board.

However, do not over-engineer this.

Use the simplest architecture that fits the existing project.

A prepared group should contain enough information to identify:

* its unique ID;
* color;
* current block/cell positions or references;
* current size;
* whether it is currently prepared/resolving.

The implementation must account for blocks moving because of gravity.

Do not allow stale prepared-group references after blocks move or are destroyed.

If the current architecture already has a suitable group/match representation, extend it rather than creating a parallel system unnecessarily.

## Building a prepared group

A prepared group is not permanently frozen.

If the player places additional blocks and they connect to an existing prepared group of the same color, the group should grow.

For example:

```text
RRR
```

is prepared.

After another red block connects:

```text
RRR
 R
```

the prepared group should become 4 blocks.

The highlight should update accordingly.

If a new group appears elsewhere, it should become another prepared group.

## Resolving a prepared group

When the player taps a prepared group:

1. Identify the prepared group.
2. Snapshot its current blocks/positions.
3. Calculate the gameplay result from the group.
4. Trigger the appropriate combat/resource event.
5. Play the existing/new explosion feedback.
6. Remove the group's blocks.
7. Apply gravity.
8. Detect newly formed groups.
9. Mark new groups as prepared.
10. Allow the player to continue.

The gameplay logic and visual animation should remain separated.

For example:

```text
Match/Group system
    ↓
MatchResult
    ↓
Combat/Resource system
    ↓
Explosion / Attack / Skill events
    ↓
Presentation / animation
```

Animations should represent gameplay results rather than deciding gameplay state.

## Cascades

```text

→ new 4-block group appears
→ new group becomes PREPARED
→ player taps it
→ explosion
```

This intentionally creates a rhythm of:

```text
PLACE → PREPARE → TAP → EXPLODE → FALL → PREPARE → TAP
```

Do not introduce automatic cascade resolution in this phase.

## Phase 1 acceptance criteria

The implementation is successful when:

* 3+ matches no longer disappear automatically.
* A valid match becomes visibly prepared/highlighted.
* The player can leave the group prepared.
* The player can place additional pieces and enlarge the group.
* The player can tap any block in the prepared group to detonate it.
* Multiple prepared groups can coexist.
* The player can choose which prepared group to detonate.
* Detonation removes only the selected group.
* Gravity still works correctly.
* New groups created by gravity become prepared rather than automatically exploding.
* No global Resolve button is introduced.
* Existing red/yellow/blue gameplay meanings continue to work.
* No unnecessary rewrite of unrelated systems is performed.

Do not automatically resolve cascades.

If gravity creates another valid 3+ group, that group should become **prepared** and highlighted.

Example:

```text
player taps group
→ explosion
→ blocks removed
→ gravity
```

---

# PHASE 2 — Special Gems

This phase should be implemented separately from Phase 1.

Do not mix the implementation of special gems into the basic prepared-group/tap-to-explode refactor until Phase 1 is stable.

## Current state

At the moment, the game only has normal colored blocks:

* Red = damage
* Yellow = energy
* Blue = guard

There are currently **no special gems selected by the player**.

The new system should introduce special gems that the player can equip/select before a battle.

Conceptually:

```text
Player loadout / pouch

[ Critical Chance ] [ Fireball ]
```

The exact UI can be minimal for now. The important part of this phase is the underlying gameplay/data architecture.

## Important distinction

A special gem is NOT simply another color.

The game should distinguish between:

### Color

Determines the basic function of a block:

```text
RED    → damage
YELLOW → energy
BLUE   → guard
```

### Special Gem

Adds a conditional effect when it participates in a matching group.

For example:

```text
Red block
+ Critical Chance gem
```

means:

> This is still a red block and participates in red matching, but the special gem can trigger an additional effect when the group is resolved.

The special gem should therefore be composable with the existing color/matching system rather than replacing it.

---

# Special Gem Concept

The player should eventually have a collection/pouch of special gems and select a limited number before entering a battle.

Selected gems are then mixed into the normal pieces that spawn during the battle.

For the initial implementation, keep the number of equipped gems small and configurable.

Example:

```text
Selected:
- Critical Chance
- Fireball
```

During the battle, these special blocks can appear among normal blocks.

---

# Special Gem Examples

These are examples for the architecture and should not be treated as final balance values.

## Red — Critical Chance

Possible behavior:

```text
Red group + Critical Chance gem
→ group size reaches required threshold
→ Critical Chance activates
→ attack receives a critical multiplier/effect
```

For example:

```text
5+ red blocks
→ critical effect
```

The exact thresholds and damage values should remain data/configuration rather than hard-coded wherever practical.

## Yellow — Fireball

Possible behavior:

```text
Yellow group + Fireball gem
→ group reaches required size
→ enough energy is available
→ consume required energy
→ launch Fireball
→ deal direct damage
```

The important design principle is:

> **Energy is a resource/fuel. The special gem determines how that energy is converted into a special action.**

Do not turn yellow matching into a generic skill button system.

## Blue — Barrier

Possible behavior:

```text
Blue group + Barrier gem
→ group reaches required size
→ generate additional guard
```

Again, exact numbers should be configurable.

---

# Special Gem Activation

A special gem should have explicit activation requirements.

For example:

```text
Fireball
- color: Yellow
- minimum_match_size: 4
- energy_cost: 3
```

When the prepared group is tapped:

1. Determine the group's color and size.
2. Identify special gems contained in the group.
3. Evaluate each gem's requirements.
4. Execute the effects of gems whose requirements are satisfied.
5. Apply the normal color effect as appropriate.
6. Resolve/remove the group.
7. Continue with gravity and prepared-group detection.

The exact order of normal color effects vs special effects should be kept modular so it can be adjusted later.

---

# Failed / Incomplete Special Gem Activation

A special gem should not necessarily block the normal match.

If a special gem is part of a valid matching group but its activation requirements are not satisfied:

```text
valid red group
+ Critical Chance gem
+ match size too small
```

then:

* the normal matching blocks can still resolve normally;
* the special effect does not activate;
* the special gem should remain on the board if that is the intended behavior.

This distinction is important.

A special gem is an optional modifier/component of a match, not a requirement for the match itself.

Do not make the entire group invalid simply because the special gem did not activate.

The exact removal behavior of an inactive special gem should be implemented in a way that can be changed easily, because this rule may be tuned during gameplay testing.

---

# Special Gems and Match Size

The architecture should explicitly distinguish:

* total number of blocks in a matching group;
* number/type of special gems inside the group;
* normal color effect;
* special-gem activation result.

Do not assume that every special gem is a separate match tier.

For example:

```text
R R R
  R*
```

could be:

```text
color = RED
match_size = 4
special_gems = [Critical Chance]
```

This should be represented as a single match result containing both the normal group information and its special-gem information.

A useful conceptual result structure is:

```text
MatchResult
    color
    block_count
    block_positions
    special_gems
    cascade_index
```

Adapt this to the existing architecture rather than blindly creating this exact class.

---

# Multiple Special Gems

The architecture should not assume that only one special gem can ever exist in a group.

A group may potentially contain multiple special gems.

For example:

```text
Yellow group
+ Fireball
+ another yellow special gem
```

The system should evaluate the contained special gems independently.

However, do not spend time implementing complex combination rules yet.

For the MVP:

* detect the special gems;
* evaluate their requirements;
* trigger valid effects;
* keep the system extensible.

---

# Player Selection / Loadout

The player should eventually be able to select a limited set of special gems before combat.

Do not build a large inventory/progression/economy system yet.

For this phase, a simple configurable loadout is enough.

For example:

```text
BattleLoadout
    selected_special_gems
```

The board/piece spawning system should use this loadout to determine which special gems can appear.

Keep special-gem definitions data-driven if the project already uses Resources/data definitions.

A special gem definition should ideally contain things such as:

```text
id
display_name
color
activation requirements
effect type
effect parameters
spawn/configuration data
```

Avoid hard-coding individual gems into the board logic.

---

# Separation of Responsibilities

Please preserve clear separation between:

### Board / Match System

Responsible for:

* block positions
* connectivity
* detecting groups
* prepared groups
* resolving which group was tapped

### Special Gem System

Responsible for:

* identifying special gems
* checking activation requirements
* generating special effects/results

### Combat / Resource System

Responsible for:

* damage
* energy
* guard
* skill/resource consumption

### Presentation

Responsible for:

* highlights
* explosions
* attack animations
* projectiles
* damage numbers
* screen feedback

The gameplay systems should produce results/events.

Presentation should react to those results.

---

# Implementation Strategy

Implement and test this in two isolated milestones.

## Milestone 1

Implement only:

```text
automatic match destruction
        ↓
prepared group
        ↓
tap group
        ↓
explode
        ↓
gravity
        ↓
new prepared groups
```

Do not introduce special gems yet.

Make sure the current red/yellow/blue behavior remains functional.

## Milestone 2

After Milestone 1 works:

```text
special gem definitions
        ↓
player-selected loadout
        ↓
special gems spawning among normal pieces
        ↓
special gem included in matching group
        ↓
tap prepared group
        ↓
evaluate special gem requirements
        ↓
trigger special effects when valid
        ↓
normal group resolution
        ↓
gravity
```

---

# Important Development Constraint

Before modifying code, inspect the existing implementation and explain briefly:

1. Which scripts/classes currently detect matches.
2. Which code currently causes automatic destruction.
3. Where the existing highlight is triggered.
4. Where gravity/cascades are handled.
5. Where red/yellow/blue effects are currently applied.
6. Which existing structures can be reused for prepared groups and match results.

Then propose the smallest set of changes required.

Do not rewrite the whole puzzle system.

Prefer extending existing systems and preserving working behavior.

Implement Phase 1 first and leave the codebase in a stable, testable state before beginning Phase 2.
