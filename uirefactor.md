# Task: Refactor the Main Gameplay UI into a Retro Arcade Fighting Interface (Godot)

## Context

This project is a mobile portrait puzzle-combat game developed in Godot. The current gameplay screen already works and includes:

- Two opposing characters: Soldier and Orc, each with a health bar.
- Two side-by-side puzzle boards.
- Colored blocks representing different combat effects.
- Combat statistics, including guard and energy.
- Three skill buttons: Burst, Heal, and Pulse.
- Touch controls for Left, Down, Right, Rotate, Drop, and Pause.

Use the attached arcade cabinet reference image as the primary visual direction.

The goal is to transform the existing gameplay UI into a polished retro arcade fighting-game interface while preserving the current game mechanics and the project's existing architecture.

**This is a UI and visual presentation refactor, not a gameplay rewrite.**

## 1. Visual direction

Create a cohesive visual style inspired by classic arcade fighting games, CRT displays, and industrial arcade cabinets.

Use the reference image for its overall visual language:

- Dark metallic panels and frames.
- Deep navy, charcoal, and steel-blue backgrounds.
- Cyan and magenta neon accents.
- Pixel-art characters and arcade-inspired typography.
- Clearly separated HUD sections.
- Strong visual hierarchy and readable combat information.
- Tactile-looking buttons with borders, highlights, shadows, and pressed states.

Suggested palette:
- Background: #17191F
- Dark panels: #202B35
- Board background: #15212B
- Grid lines: muted blue-gray
- Cyan accents: #28D7E5
- Magenta accents: #E84B79

Preserve the existing combat colors and their meanings. Red, yellow, and green blocks must remain immediately distinguishable.

The result should feel like playing a retro arcade fighting game, not like using a generic mobile application.

## 2. First inspect the existing project

Before modifying anything:

1. Identify the current main gameplay scene and its associated scripts.
2. Inspect the scene hierarchy and identify the existing UI nodes, puzzle boards, character sprites, health bars, skill buttons, and touch controls.
3. Determine which elements are implemented using Control nodes, Containers, custom drawing, or other Godot UI mechanisms.
4. Identify how the current layout adapts to portrait resolutions and different screen sizes.
5. Determine which UI elements are connected to gameplay logic through signals, scripts, or references.

Reuse existing scenes, nodes, scripts, and assets wherever practical.

Do not assume node names or file paths. Inspect the project and adapt the implementation to its actual structure.

Before editing, briefly summarize the proposed changes and identify any architectural constraints.

## 3. Main screen composition

Reorganize the existing screen into the following visual hierarchy:

### A. Compact top HUD

- Replace the plain gray background with a dark arcade-style interface.
- Keep the block-effect legend compact and readable.
- Remove redundant information and unnecessary empty legend entries where appropriate.
- Introduce subtle panel borders, small indicators, and restrained neon accents.
- Avoid a large decorative title if it would consume valuable gameplay space.

### B. Character combat HUD

- Improve the presentation of the Soldier and Orc.
- Preserve the existing character sprites and their visual identity.
- Give each character a clear health bar and a compact status area.
- Improve the presentation of health, guard, and energy.
- Use distinct accent colors to help differentiate the two sides.
- Add a subtle central VS separator only if it fits the available space.
- Ensure that health and status values remain readable at mobile scale.

Avoid unnecessarily enlarging the character panels or pushing the puzzle boards down.

### C. Puzzle boards

The two puzzle boards are the primary gameplay elements and must remain the visual focus.

- Preserve their current dimensions, grid structure, cell arrangement, and gameplay behavior unless a layout adjustment is necessary.
- Replace the flat presentation with a dark inset panel surrounded by a restrained metallic or neon frame.
- Keep the grid lines visible but less prominent than the blocks.
- Give blocks subtle depth through borders, highlights, and shadows, without changing their logical colors or gameplay representation.
- Ensure that the left and right boards remain aligned and visually balanced.

Use decorative frames around the existing board components rather than rebuilding the boards from scratch.

The reference image uses a strong blue-versus-magenta composition. Apply this selectively so that it does not compete with block colors or make the interface visually noisy.

### D. Skill buttons

Restyle Burst, Heal, and Pulse as arcade-style action buttons.

- Make each skill visually distinct.
- Use icons, labels, costs, and keyboard hints only where they are already supported or relevant.
- Improve disabled, available, pressed, and unavailable states.
- Preserve their existing signals and gameplay behavior.
- Make the controls easy to understand without relying exclusively on color.

Do not implement new skills or change their costs as part of this task.

### E. Touch controls

Restyle Left, Down, Right, Rotate, Drop, and Pause to match the arcade theme.

- Use a coherent visual language for directional and action controls.
- Make Rotate and Drop easy to distinguish from movement.
- Preserve Pause and its existing behavior.
- Provide clear visual feedback when a control is pressed.
- Maintain comfortable touch targets and sufficient spacing to prevent accidental input.

The reference image contains a physical joystick and arcade buttons. Treat these as visual inspiration, not a requirement to reproduce a physical cabinet literally.

The game must remain comfortable to play on a touchscreen. Do not replace working touch controls with a decorative joystick that has no functional input.

If a virtual joystick would require changing input handling, leave that change out of scope unless the existing project already supports it.

## 4. Background and arcade frame

Replace the flat gray gameplay background with a dark, restrained arcade environment.

The preferred approach is a combination of:

- A charcoal or deep navy background.
- Subtle metallic paneling around the HUD and board edges.
- Thin cyan and magenta accent lines.
- Optional, very subtle CRT scanlines or vignette effects.
- Small industrial details that reinforce the arcade cabinet aesthetic.

Keep the decorative elements concentrated around the outer edges and between UI sections.

Do not place detailed textures behind the puzzle cells or important text.

Do not create a large, illustrated fighting arena or a full-screen cabinet illustration that reduces the usable gameplay area.

The interface should suggest an arcade machine while still feeling like a native portrait mobile game.

## 5. Godot implementation requirements

Implement the visual changes using the project's existing Godot version and conventions.

Prefer reusable UI components and shared styling over duplicating custom styling across every control.

Where appropriate, consider:

- Control nodes and Containers for layout.
- Anchors and size flags for responsive positioning.
- Theme resources and StyleBoxFlat resources for consistent panels and buttons.
- NinePatchRect or suitable reusable textures for frames that need scalable borders.
- TextureRect for decorative textures and sprites.
- Reusable scenes for common panel and button styles.

These are implementation options, not mandatory replacements for an existing architecture that already works well.

Avoid hardcoding the entire interface to the dimensions of the reference screenshot.

The layout must adapt to different portrait resolutions and aspect ratios without overlapping controls, clipping text, distorting sprites, or making touch targets too small.

Keep gameplay logic separate from presentation logic wherever practical.

Do not introduce unnecessary autoloads, managers, dependencies, or new architectural layers just to implement the visual refactor.

## 6. Preserve functionality

This task must not break or redesign the existing gameplay systems.

Preserve:

- Board logic, cell coordinates, and block spawning.
- Existing block colors and their effects.
- Character health and combat status updates.
- Skill activation and energy costs.
- Movement, rotation, drop, and pause behavior.
- Existing signals, script references, and gameplay state.
- Any existing prepared-group highlighting or block-resolution interactions.

Do not replace functional gameplay components with static visual mockups.

Do not duplicate gameplay state inside the UI.

If a visual change requires modifying a script, keep the modification minimal and explain why it is necessary.

## 7. Scope and implementation process

Implement this as an incremental refactor.

**Phase 1 — Structure and layout**
- Identify the existing scene and its dependencies.
- Establish the new background, panel hierarchy, and responsive layout.
- Preserve all current functionality.

**Phase 2 — Visual styling**
- Apply the arcade palette, metallic frames, HUD styling, skill button styling, and touch-control styling.
- Reuse existing sprites and assets wherever possible.
- Add simple visual details only when they improve hierarchy or readability.

**Phase 3 — Validation and polish**
- Run the project and inspect the actual gameplay screen.
- Verify that the two boards, characters, HUD, skills, and controls remain visible and functional.
- Check at least the project's target portrait resolution and a narrower or taller portrait aspect ratio.
- Fix layout issues and remove unnecessary decorative elements.

Do not implement all phases through a single massive rewrite. Make focused changes that are easy to review and test.

## 8. Expected result

Deliver a working Godot gameplay scene that retains the current game's layout and mechanics while achieving a coherent retro arcade fighting-game aesthetic.

The result should have:

- A dark industrial arcade background.
- A visually distinctive but compact combat HUD.
- Clearly framed puzzle boards.
- Consistent arcade-style skill and touch controls.
- A restrained cyan/magenta lighting scheme.
- Preserved pixel-art characters and block colors.
- Responsive portrait layout and readable mobile controls.

Prioritize gameplay readability, visual consistency, and maintainability over decorative complexity.

After implementation, summarize:
1. Which scenes and scripts were changed.
2. Which reusable UI components or resources were created.
3. How the layout adapts to portrait screens.
4. Which existing behaviors were verified.
5. Any remaining visual assets or polish that would benefit from a later iteration.