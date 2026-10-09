# Test Harness

## Prepared groups and special gems

Run the focused gameplay tests from the project root:

```sh
godot --headless --path . --script tests/PreparedGroups_test.gd
godot --headless --path . --script tests/PreparedGroupTouchTarget_test.gd
godot --headless --path . --script tests/PreparedGroupEnemyTurnInput_test.gd
godot --headless --path . --script tests/SpecialGemManager_test.gd
godot --headless --path . --script tests/PieceSpawner_test.gd
```

The prepared-group test checks that matches persist and grow until tapped, that
only the tapped group is removed, and that other prepared groups survive.
The touch-target test verifies a prepared chain can be tapped through the
empty space enclosed by its highlighted cells.
The enemy-turn input test verifies prepared matches remain tappable while the
enemy is acting, without enabling other player controls.
The special-gem tests cover color-based spawning, configured activation
requirements, energy costs, and inactive gems remaining configurable.

## Mobile input smoke test

Run the scene-level gesture and touch-control test from the project root:

```sh
godot --headless --path . --script tests/MobileInput_test.gd
```

The test loads the battle scene and verifies left/right/down/up swipes, tap
dead-zone handling, pause/resume, and the on-screen hard-drop control.

## Physical Android device check

1. Export the project as an Android debug APK in Godot and install it on the
   connected device.
2. Start a battle and swipe left/right over the game area; confirm the active
   piece moves one column per swipe.
3. Swipe down to soft-drop one row and swipe up to rotate once. Short taps
   should not move or rotate the piece.
4. Use the on-screen Left, Down, Right, Rotate, and Drop controls; confirm each
   action works and that the skill buttons remain usable.
5. Tap Pause, confirm the battle freezes, then tap Resume.
6. Repeat after rotating the device only if the project is configured for that
   orientation; the project currently requests portrait orientation.
