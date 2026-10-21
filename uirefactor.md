# Task: Implement the Arcade Cabinet Layout and Control Deck

## Objective

The current Godot gameplay UI has already received an initial visual styling pass. The dark background, cyan and magenta board frames, character HUDs, and general color palette are in place.

However, the main visual elements that define the intended arcade cabinet aesthetic are still missing:

1. A designed arcade-style background and outer cabinet frame.
2. A dedicated lower control deck inspired by a physical arcade machine.
3. A redesigned arrangement of the touch controls, including a virtual joystick and distinct action buttons.
4. A better use of vertical space to make the gameplay screen feel like a cohesive arcade machine.

Use the two attached images as references:
- The current screenshot shows the actual implementation and layout that must be improved.
- The arcade cabinet concept image shows the intended visual direction and control layout.

**Implement these structural and visual changes in the existing Godot project. Do not merely restyle the existing rectangular buttons.**

## 1. Inspect the current implementation first

Before making changes, inspect the actual gameplay scene, its scripts, node hierarchy, layout containers, anchors, and input handling.

Identify:
- The root gameplay Control or equivalent.
- The background and existing decorative elements.
- The character HUDs and puzzle boards.
- The skill buttons.
- The movement, rotation, drop, and pause controls.
- The signals and scripts responsible for handling user input.

Determine which existing elements can be repositioned and which require a new reusable scene or visual component.

Briefly explain the intended structural changes before implementing them. Do not assume node names or file paths.

## 2. Create an arcade cabinet background

Replace the current plain, nearly black background with a designed retro arcade environment.

The background should visually resemble the inside of a dark, futuristic arcade cabinet, using:

- A deep charcoal or navy base.
- Subtle industrial metal panels and recessed sections.
- Thin cyan and magenta illuminated accents.
- Pixel-art-inspired borders, corner details, and small mechanical elements.
- A restrained CRT-inspired finish, if appropriate.

Create a clear visual distinction between the main gameplay screen and the surrounding cabinet frame.

The background must remain behind the existing gameplay elements. It must not obscure the boards, characters, text, or controls.

Prefer reusable Godot UI resources, scalable frame textures, NinePatchRect, TextureRect, or custom drawing where appropriate.

If additional graphical assets are necessary, identify the exact assets required and use existing project assets where possible. Do not substitute the requested cabinet design with another flat background or a collection of generic colored borders.

Avoid excessive textures, heavy glow effects, and decorative details that reduce readability or performance on mobile.

## 3. Redesign the bottom section as an arcade control deck

The most important structural change is to replace the current uniform rectangular control layout with a visually integrated arcade control deck.

Create a distinct lower panel that looks like a physical control surface embedded in the cabinet.

The panel should have a dark metallic surface, a defined outer frame, subtle highlights, and restrained neon illumination.

### Left side: virtual joystick

Replace the current Left, Down, and Right rectangular buttons with a virtual joystick.

The joystick should visually include:
- A circular recessed base.
- A visible central stick and rounded knob.
- A red or magenta accent consistent with the arcade reference.
- A clear pressed or active state.

The joystick must be functional, not decorative.

Inspect the existing input system and implement touch interaction that supports the game's required directional movement. Prefer intuitive dragging or directional touch input, with appropriate handling for mobile screens.

Preserve the existing movement behavior and repeat timing wherever possible. Prevent the joystick from generating unintended repeated touches or leaving movement stuck when the player releases their finger.

If implementing a virtual joystick would require a significant gameplay input rewrite, explain the required changes before proceeding.

### Right side: action buttons

Create a dedicated group of arcade-style action buttons.

Use separate visual treatments to distinguish:
- Rotate.
- Drop.
- Pause.
- The primary action, if the existing gameplay mechanics support it.

Use circular or rounded physical-button designs with a raised appearance, highlights, shadows, and pressed states.

Use blue, yellow, green, and magenta accents selectively. Keep the primary action visually prominent without making it excessively large.

Preserve the existing button actions and signal connections. Do not change the underlying gameplay mechanics.

Do not invent new actions or implement an unrequested combat mechanic.

### Skill buttons

Keep Burst, Heal, and Pulse in a separate row immediately above the control deck.

Restyle them as compact illuminated arcade buttons or recessed skill panels. Preserve their current functionality, costs, availability states, and labels.

Ensure that the skill row and the control deck remain visually distinct.

## 4. Rework the vertical layout

The current layout has a large empty area between the puzzle boards and the controls. Use this space more effectively.

Reorganize the screen into a cohesive vertical composition:

1. Compact combat legend.
2. Character sprites and combat HUDs.
3. The two puzzle boards, which remain the main gameplay focus.
4. A compact skill-button row.
5. A dedicated arcade control deck at the bottom.

Reduce unnecessary vertical gaps and integrate the sections visually into the cabinet design.

Do not simply scale up the controls or move the entire layout upward.

Keep both puzzle boards visible and usable, with enough space for their complete grids and existing interactions.

The character sprites should remain recognizable and should not overlap the HUD or boards.

The bottom control deck must fit above the device's bottom safe area and must not be clipped by the screen edge.

## 5. Godot layout and implementation

Implement the changes using the project's existing Godot version and architecture.

Use responsive Control layouts, appropriate Containers, anchors, size flags, and reusable scenes or Theme resources where suitable.

Avoid hardcoding the layout to the exact dimensions of either reference image.

The interface must adapt to portrait screens with different aspect ratios.

If the current scene has tightly coupled layout logic, refactor only the parts needed to support the new composition.

Separate visual presentation from gameplay logic. Keep the board implementation, combat state, and game rules unchanged.

Do not replace existing working components with static mockups.

Do not add unnecessary autoloads, managers, or architectural layers.

## 6. Preserve functionality

The following must continue to work:

- Both puzzle boards and their current grid dimensions.
- Block spawning, movement, rotation, and dropping.
- Character health and status updates.
- Burst, Heal, and Pulse.
- Pause and resume.
- Existing touch interactions and gameplay signals.
- Any existing group highlighting or block-resolution interactions.

Verify that all new controls trigger the same intended actions as their existing counterparts.

## 7. Implementation workflow

Implement this as a focused second visual iteration.

**Phase 1: Layout and cabinet structure**
- Reorganize the scene hierarchy as needed.
- Add the cabinet background and frame.
- Create the lower control deck.
- Reposition the skill row and controls.

**Phase 2: Control implementation**
- Implement the virtual joystick interaction.
- Create the new action-button visuals and pressed states.
- Connect them to the existing input and gameplay systems.

**Phase 3: Validation**
- Run the game and inspect the actual scene.
- Test the joystick and every action button.
- Verify the complete layout at the target portrait resolution and at least one different portrait aspect ratio.
- Fix clipping, overlap, excessive empty space, and insufficient touch targets.

Do not stop after creating a plan or a static visual mockup. Implement the changes in the actual project files, then report what was changed and what still needs testing.

## Expected result

The final screen should feel like a playable retro arcade fighting machine adapted for mobile, rather than a conventional mobile UI with neon borders.

The cabinet background, character HUD, puzzle boards, skill row, virtual joystick, and action buttons should form one coherent design.

Prioritize the physical arcade feeling of the control deck and the outer frame while preserving the puzzle boards as the primary gameplay area.