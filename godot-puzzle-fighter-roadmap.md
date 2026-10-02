# Godot 4.6 Implementation Roadmap for Puzzle Combat PvE MVP

This document transforms the concept from `readme.txt` into a practical step-by-step development plan for building the game in Godot 4.6.

The goal is to build the MVP in a way that is deterministic, testable, and easy to extend later. The order below is designed so the core loop works first:

`place piece -> match -> explode -> attack -> enemy responds -> adjust -> win/lose`

---

## 1. Project setup and scope lock

### Goal
Create a minimal Godot 4.6 project with the exact MVP boundaries defined in the design document.

### Steps
1. Create a new Godot 4.6 project in a clean folder.
2. Configure the project for portrait mobile orientation.
3. Define the MVP scope clearly:
   - 1 player board
   - 1 enemy board
   - 4 colors
   - 2-block pieces
   - rotation, horizontal movement, soft drop, quick drop
   - match detection of 3+ connected blocks
   - gravity and cascades
   - combat damage and HP
   - 1 character and 1 enemy
   - 1 to 3 skills
4. Do not add optional systems yet: shops, inventory, progression, multiplayer, campaign, persistent saves.
5. Create a basic folder structure:
   - `res://scenes/`
   - `res://scripts/`
   - `res://resources/`
   - `res://assets/`
   - `res://tests/`

### Recommended project structure
```text
res://
├── scenes/
│   ├── main/
│   ├── battle/
│   ├── board/
│   ├── pieces/
│   ├── characters/
│   ├── enemies/
│   └── ui/
├── scripts/
│   ├── core/
│   ├── battle/
│   ├── board/
│   ├── pieces/
│   ├── combat/
│   ├── enemies/
│   ├── skills/
│   └── ui/
├── resources/
│   ├── pieces/
│   ├── characters/
│   ├── enemies/
│   ├── skills/
│   ├── colors/
│   └── stages/
├── assets/
│   ├── sprites/
│   ├── effects/
│   ├── audio/
│   └── fonts/
├── tests/
└── project.godot
```

### Deliverable
A project shell with a single battle scene and empty core scripts ready for development.

---

## 2. Define the battle state machine

### Goal
Create an explicit, deterministic state model so the game knows what is allowed at any given moment.

### States to implement first
- `INITIALIZING`
- `PLAYING`
- `PIECE_ACTIVE`
- `RESOLVING`
- `ENEMY_ACTION`
- `PLAYER_DEFEATED`
- `ENEMY_DEFEATED`
- `VICTORY`
- `DEFEAT`

### Steps
1. Create a `BattleState` enum.
2. Create a `BattleManager` script that owns the current state.
3. Add functions like:
   - `start_battle()`
   - `set_state(new_state)`
   - `can_player_act()`
   - `can_enemy_act()`
4. Restrict input when the state is not `PLAYING` or `PIECE_ACTIVE`.
5. Ensure that when a cascade is resolving, no new placement is allowed.

### Design rule
The state system must prevent race conditions between board logic, animations, and combat resolution.

### Deliverable
A functioning battle state controller that blocks invalid actions at the right times.

---

## 3. Create the data model

### Goal
Build a clean data layer that separates gameplay logic from visuals.

### Create resource scripts
Implement these as `Resource`-based definitions:

- `PieceDefinition`
  - id
  - color
  - type
  - visual name / sprite reference
  - effects / metadata

- `ColorDefinition`
  - id
  - name
  - attack behavior / combat role
  - display color

- `CharacterDefinition`
  - id
  - max_hp
  - skills
  - attack modifiers

- `EnemyDefinition`
  - id
  - max_hp
  - attack pattern
  - skill metadata

- `SkillDefinition`
  - id
  - cost
  - effect type
  - target
  - parameters

- `StageDefinition`
  - board size
  - available colors
  - enemy definition
  - difficulty parameters

### Steps
1. Create each resource as a `.tres` or `.gd` data class.
2. Keep all gameplay definitions data-driven rather than hardcoded in the board logic.
3. Keep visual metadata separate from combat logic.

### Deliverable
A flexible definition layer for colors, pieces, players, enemies, and skills.

---

## 4. Build the board logic

### Goal
Create the core grid logic for both player and enemy boards.

### Board dimensions
Use a configurable grid size such as:
- 6 columns
- 10 rows

### Board responsibilities
- Store occupied cells
- Determine whether a cell is empty
- Validate movement and rotation positions
- Apply gravity
- Detect matches
- Resolve cascades

### Steps
1. Create `BoardManager`.
2. Add a grid-based storage structure using integer coordinates.
3. Define a logical board coordinate system separate from visual positions.
4. Create a `BoardCell` or board helper system that tracks cells as empty or occupied.
5. Implement `can_move_piece_to(position)`.
6. Implement `can_rotate_piece(piece)`.
7. Implement `lock_piece()` which transfers active piece blocks into the board state.
8. Add the concept of `BoardView` to separate rendering from logic.

### Key rule
The logic must not depend on physics or node positions. Use deterministic grid math instead.

### Deliverable
A board system that can place, move, fall, rotate, lock, and resolve cells mathematically.

---

## 5. Build the piece model

### Goal
Define how two-block pieces spawn, move, rotate, and lock.

### Piece structure
Each piece should contain:
- `id`
- `color`
- `blocks`
- `orientation`
- `logical_position`
- `is_active`
- `is_locked`
- `container_piece`

### Block structure
Each block should have:
- color
- type
- owner piece
- cell coordinates
- state

### Steps
1. Create `Piece` script.
2. Define a piece as two connected blocks.
3. Implement the rotation matrix for 90-degree turns.
4. Validate rotation against:
   - board bounds
   - occupied cells
   - resulting block positions
5. Implement `move_left()`, `move_right()`, `soft_drop()`, and `hard_drop()`.
6. Implement `spawn()`, `lock()`, and `destroy()`.
7. Keep visual interpolation in a separate view layer.

### Recommended behavior
- Soft drop: move down one row when allowed.
- Hard drop: drop until locked.
- Rotation: deterministic and grid-based without using physics.

### Deliverable
A playable piece model with movement and rotation rules that work under all board constraints.

---

## 6. Create the input abstraction layer

### Goal
Avoid coupling puzzle logic to touch events.

### Input architecture
Create an `InputController` abstraction that translates input into board actions.

### Supported commands
- move left
- move right
- soft drop
- hard drop
- rotate
- pause / cancel

### Steps
1. Create an `InputController` script.
2. Bind touch gestures and keyboard controls to the same commands.
3. Map:
   - swipe left -> move left
   - swipe right -> move right
   - swipe down -> soft drop / fast fall
   - tap or special gesture -> rotate
4. Keep commands as abstract actions rather than direct `InputEvent` calls.
5. Make debugging easier by allowing keyboard simulation in desktop builds.

### Deliverable
An input layer that can later support alternate control schemes and test automation.

---

## 7. Implement match detection

### Goal
Detect groups of same-color blocks connected orthogonally.

### Match rules
- Only horizontal and vertical connectivity count.
- Diagonal connections do not count.
- A valid group is usually 3+ connected blocks.
- Group detection must be deterministic and repeatable.

### Steps
1. Create `MatchManager`.
2. Scan the board for connected blocks by color.
3. Use BFS or flood-fill for region detection.
4. Collect groups of size >= 3.
5. Mark all blocks in each group as matched.
6. Remove duplicates from multiple detection pass results.
7. Return a `MatchResult` with:
   - `groups`
   - `match_count`
   - `total_blocks_destroyed`
   - `affected_colors`

### Important design rule
Match detection must happen after a piece locks and board state updates, not based on animation triggers.

### Deliverable
A board that can detect valid matches, track match sizes, and prepare attack generation.

---

## 8. Build the cascade system

### Goal
Support chain reactions after each resolved match.

### Cascade model
A cascade occurs when match resolution causes blocks to fall and create another match.

### Required metrics
Track:
- `match_count`
- `cascade_count`
- `total_blocks_destroyed`
- `attack_power`
- `combo_multiplier`

### Steps
1. Create `CascadeManager` or integrate cascade handling into `MatchManager`.
2. After each match cleanup:
   - remove matched blocks
   - apply gravity
   - detect another match
   - repeat until no matches remain
3. Increment cascade iteration for each round.
4. Save the final total stats for combat resolution.
5. Emit game events after each resolution to support UI and debug logs.

### Deliverable
A deterministic cascade resolver that can chain multiple match resolutions from the same action.

---

## 9. Create the combat result pipeline

### Goal
Convert puzzle resolution into game actions and damage.

### Combat flow
`Match -> MatchResult -> AttackCalculation -> AttackEvent -> CombatState`

### Steps
1. Create `CombatManager`.
2. Define `AttackEvent` data:
   - source
   - target
   - color
   - amount
   - cascade bonuses
   - combo multiplier
   - special effects
3. Create a central damage function such as `apply_damage(target, amount)`.
4. Keep HP mutation inside `CombatManager` and not directly inside board or UI scripts.
5. Update character and enemy HP using centralized combat logic.
6. Emit damage events for UI feedback.

### Damage formula
Use a formula that is flexible but easy to tune:

```text
base_damage
+ size_bonus
× cascade_multiplier
× character_modifier
```

### Deliverable
A combat layer that converts board resolutions into consistent, testable damage events.

---

## 10. Implement color-based combat roles

### Goal
Give each color a role without making match logic complicated.

### Suggested MVP mapping
- Red -> damage
- Blue -> defense
- Green -> healing / sustain
- Yellow -> energy / skill gain

### Steps
1. Define `ColorDefinition` values for all four colors.
2. Build a simple attack calculator that reads color metadata.
3. Allow later lock-in changes without touching match detection.
4. Keep combat result generation independent from visual representation.

### Deliverable
A flexible color system where combat effects are driven by data, not overwritten by hardcoded match logic.

---

## 11. Add HP, battle health, and victory/defeat rules

### Goal
Define win/lose conditions and secure a clean battle loop.

### Rules
- Player wins when `enemy_hp <= 0`.
- Player loses when `player_hp <= 0`.
- No full-board loss condition in the MVP.
- If an enemy dies during a cascade, the enemy should not continue taking queued actions.

### Steps
1. Create `CombatState` with `current_hp` and `max_hp`.
2. Add `take_damage()`, `heal()`, and `apply_effect()` helpers.
3. Update `BattleManager` to react to victory/defeat transitions.
4. Add a reset flow to replay the battle.
5. Add a return-to-menu flow.

### Deliverable
An explicit end-of-battle loop with deterministic victory/defeat evaluation.

---

## 12. Create the enemy board and action sequence

### Goal
Add the enemy side of the battle so the fight feels reactive and readable.

### Enemy board behavior
The enemy should:
- spawn pieces
- move or rotate them
- lock them
- resolve the board
- generate attack actions
- wait and repeat

### Steps
1. Create `EnemyController`.
2. Create `EnemyActionSequence` as a list of actions executed in order.
3. Basic enemy pattern example:
   - spawn
   - move
   - rotate
   - lock
   - resolve
   - attack
   - wait
4. Keep the first enemy deterministic and predictable.
5. Make it visible to the player so the enemy is readable, not “smart” in a complex way.

### Deliverable
A simple enemy turn system that produces readable pressure and anticipatory decisions.

---

## 13. Visualize enemy actions in the same system

### Goal
Use the same board and piece logic to show enemy actions rather than building a separate visual system.

### Steps
1. The enemy should reuse `Piece`, `BoardManager`, and `MatchManager` logic.
2. Create enemy action animations or previews that reflect the logical action sequence.
3. Add enemy UI indicators such as:
   - prepared attack
   - damage amount
   - skill readiness
   - timer / turn indicator
4. Keep these indicators as UI, not gameplay logic.

### Deliverable
Enemy actions that are visible, understandable, and consistent with the player’s own board flow.

---

## 14. Add the skill system

### Goal
Implement a minimal skill layer that interacts with board and combat without breaking the architecture.

### MVP skill expectations
- Up to 3 skills
- skills may modify the board, deal damage, heal, convert colors, or alter state
- skills should go through `SkillManager`

### Steps
1. Create `SkillManager`.
2. Define `SkillDefinition` data resources.
3. Add a simple skill execution flow:
   - player input
   - `SkillManager`
   - `SkillEffect`
   - `BoardManager` / `CombatManager`
   - state change
   - visual feedback
4. Use a small number of skills only in the MVP.

### Deliverable
A controllable skill layer with clean separation between logic and presentation.

---

## 15. Implement the player and enemy characters

### Goal
Create the minimal combat actors for the first playable battle.

### Character data
- max HP
- color modifiers
- skills
- attack multipliers

### Steps
1. Create `PlayerCharacter` and `EnemyCharacter` data objects.
2. Set one default player and one default enemy.
3. Store them in `BattleManager` or `CombatManager`.
4. Keep the architecture extensible for future multiple fighters.

### Deliverable
A battle with the minimum necessary actor definitions to run the prototype.

---

## 16. Create the event bus

### Goal
Decouple gameplay logic from visual/UI systems using events.

### Initial events
- `piece_spawned`
- `piece_moved`
- `piece_locked`
- `match_found`
- `match_destroyed`
- `cascade_started`
- `cascade_finished`
- `attack_created`
- `damage_received`
- `hp_changed`
- `skill_used`
- `enemy_action_started`
- `enemy_action_finished`
- `battle_won`
- `battle_lost`

### Steps
1. Create a shared `EventBus` singleton.
2. Emit gameplay events from logic systems.
3. Let HUD and effects systems subscribe to events.
4. Ensure the UI reacts to state changes without owning gameplay rules.

### Deliverable
A modular event-driven design that scales beyond the MVP.

---

## 17. Build the battle scene and board scene hierarchy

### Goal
Assemble the playable screen in Godot with the correct UI and board structure.

### Suggested hierarchy
- `Main`
  - `BattleScene`
    - `PlayerBoardContainer`
      - `BoardView`
      - `PieceView`
    - `EnemyBoardContainer`
      - `EnemyBoardView`
    - `CombatUI`
    - `EnemyUI`
    - `NextPiecePanel`
    - `SkillPanel`
    - `BattleOverlay`

### Steps
1. Create the battle scene in the editor.
2. Create a board node for the player and another for the enemy.
3. Add a UI layer for HP, skills, combo, and damage indicators.
4. Add placeholders for animations and particles.
5. Keep the scene graph simple at first; do not over-engineer presentation yet.

### Deliverable
A working battle layout with all required visible components in place.

---

## 18. Build the visual representation layer

### Goal
Make the logic visible without allowing visuals to drive rules.

### Steps
1. Create `BoardView` to render cells, blocks, and backgrounds.
2. Create `PieceView` to render piece blocks visually.
3. Add effects for:
   - match highlight
   - explosion
   - attack spark
   - damage numbers
   - combo indicator
   - enemy attack indicator
4. Keep effects as response to state change, not as the source of truth.

### Deliverable
A responsive and readable presentation layer that visualizes battle events clearly.

---

## 19. Connect logic to UI and effects

### Goal
Make the game feel reactive and communicative.

### Visual feedback to implement
- piece placed
- match detected
- explosion
- attack generated
- damage taken
- combo count
- cascade count
- enemy attack
- victory
- defeat

### Steps
1. Subscribe UI to relevant events.
2. Update HP bars and labels from `hp_changed` events.
3. Show attack information when combat events are created.
4. Trigger particle and sound effects synced to logic events.
5. Ensure every important event communicates: what happened, why it happened, and the consequence.

### Deliverable
An understandable game loop that communicates status to the player without ambiguity.

---

## 20. Implement deterministic testing support

### Goal
Make the core logic easy to test without animations or full scenes.

### Priority tests
- Board placement and boundaries
- Movement and rotation validation
- Gravity application
- Match detection
- Diagonal exclusion
- Multi-group match detection
- Cascade resolution and combo counting
- Combat damage application
- HP death checks
- Enemy action sequence behavior

### Steps
1. Create a test scene or use Godot’s unit-test pattern in scripts.
2. Test board logic directly from script objects.
3. Use deterministic seeds for piece generation and randomization.
4. Log match, cascade, and damage outputs for debugging.

### Deliverable
A testable game logic stack that can be validated without visual dependency.

---

## 21. Add gameplay tuning and balancing

### Goal
Tune the MVP mechanics to make the loop satisfying without overbuilding systems.

### Tune the following
- match minimum size
- board dimensions
- drop speed
- quick drop behavior
- damage per block
- cascade multiplier
- combo multiplier
- enemy attack timing and intensity
- skill costs and effects

### Steps
1. Start with simple formulas.
2. Balance by measuring whether the loop feels satisfying.
3. Adjust only after the core gameplay loop is working.
4. Do not add new systems before the current loop is strong.

### Deliverable
A fun and readable core loop with a balanced rhythm of puzzle play and enemy pressure.

---

## 22. Add the main battle loop and flow control

### Goal
Combine all pieces into one final play loop.

### Sequence
1. Battle initializes
2. Player board created
3. Enemy board created
4. Pieces spawn
5. Player can move and rotate
6. Player locks piece
7. Board resolves matches
8. Cascades trigger
9. Combat damage applies
10. Enemy action executes
11. Repeat until a win or defeat state is reached

### Flow control logic
- Only one active piece at a time
- resolution blocks input
- enemy turn occurs only after player resolution ends
- battle ends when HP reaches zero

### Deliverable
A complete playable battle loop that can be replayed and restarted.

---

## 23. Build a minimal playable prototype

### Goal
Produce a simple but complete MVP that demonstrates the core loop.

### MVP checklist
- 1 player board
- 1 enemy board
- 4 colors
- 2-block pieces
- rotation
- movement
- fall behavior
- lock
- match detection of 3+
- remove matched blocks
- gravity
- cascades
- combat damage
- HP bars
- 1 skill set
- 1 enemy pattern
- restart / menu flow

### Steps
1. Assemble every core script and scene into a playable prototype.
2. Test one full round from start to finish.
3. Validate that the game loop is satisfying.
4. Fix rule-breaking edge cases before adding features.

### Deliverable
The MVP version of the game ready for user testing.

---

## 24. Hardening, polish, and expansion readiness

### Goal
Once MVP works, make it easier to extend without rewriting the architecture.

### Focus areas
- smooth animations
- sound effects
- better feedback for attack and match events
- board scaling to mobile screen sizes
- deterministic testing and seeds
- more enemy patterns
- more character definitions
- additional skills and special blocks later

### Do not add yet
- gacha
- economy
- progression systems
- campaign story
- multiplayer
- online backend
- unrelated content layers

### Deliverable
A clean foundation that supports future deeper mechanics without sacrificing the core game loop.

---

## 25. Recommended execution order in practice

If you want a real implementation sequence, follow this exact order:

1. Create Godot project and folder structure.
2. Define battle states and turn flow.
3. Build board data structures and coordinates.
4. Build piece spawning and rotation logic.
5. Add movement and locking.
6. Add match detection.
7. Add gravity and cascade resolution.
8. Add combat calculations and HP.
9. Add enemy controller and action sequence.
10. Add UI and battle scene layout.
11. Add event bus and effects.
12. Add skill system.
13. Add testing and tuning.
14. Build final playable MVP and validate the fun loop.

---

## 26. Recommended Godot script set

Use this as a practical starting script list:

- `BattleManager.gd`
- `BoardManager.gd`
- `Piece.gd`
- `PieceDefinition.gd`
- `ColorDefinition.gd`
- `MatchManager.gd`
- `CascadeManager.gd`
- `CombatManager.gd`
- `InputController.gd`
- `EnemyController.gd`
- `EnemyActionSequence.gd`
- `SkillManager.gd`
- `SkillDefinition.gd`
- `EventBus.gd`
- `BoardView.gd`
- `PieceView.gd`
- `CombatUI.gd`
- `EnemyUI.gd`
- `Main.gd`

---

## 27. Final success rule

The MVP should not be considered complete until this sequence feels satisfying in practice:

`observe piece -> decide placement -> lock -> create match -> explode -> deal damage -> trigger cascade -> read enemy response -> adapt -> repeat`

If this loop feels fun with only:
- one character
- one enemy
- four colors
- two-block pieces
- up to three skills

then the project has a viable base for later expansion.

---

## 28. Recommended next step after this roadmap

The next step is to start implementing in this order:

1. `BattleManager` and battle state enum
2. `BoardManager` grid logic
3. `Piece` movement and rotation
4. `MatchManager`
5. `CombatManager`
6. `EnemyController`
7. `BattleScene` UI and board layout

This creates the minimum viable playable version before the project grows.
