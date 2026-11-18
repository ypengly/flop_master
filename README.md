# Flop Master

A 3D ragdoll physics game about glorious failure, built in **Godot 4.4** (GDScript, Jolt Physics).
Guide a floppy human through six absurd levels, and score points for spectacular flops as well as
for actually finishing.

## Run it

1. Install **Godot 4.4 or newer** (standard build, no .NET needed): https://godotengine.org/download
2. Open Godot, click **Import**, choose `project.godot` in this folder, then press **F5** (or run
   `godot --path .` from a terminal).

No external assets are required. All sounds and music are synthesized at startup, and all models,
levels and UI are built from code.

## Controls (all remappable in Settings)

| Action | Default | Notes |
|---|---|---|
| Move | W A S D / arrows / left stick | Relative to the camera |
| Run | Shift | Faster, but you trip at high speed |
| Jump | Space | Also pulls you up when hanging from a ledge |
| Dive | C | Launches you forward into a ragdoll tumble |
| Grab | E (hold) | Grab ledges and objects; drains grip |
| Push | F | Shoves crates and props |
| Get up | R | Stand up sooner. **Hold R** to give up and return to the last checkpoint |
| Restart level | Backspace | |
| Pause | Esc | Resume, restart, end run and score it, settings, quit |
| Camera | Mouse | |

## Gameplay

* **Flop Score** combines airborne distance, tumbles, flips, collision intensity, objects knocked
  over, the size of falls, stunt variety and collectibles. Ratings run from *Mildly Wobbly* through
  *Human Noodle* and *Professional Disaster* to *Certified Catastrophe* and *Flop Master Supreme*.
* Finishing a level adds a completion bonus plus a time bonus against the level's par time, so
  failing spectacularly never beats actually finishing.
* **Pausing → "End Run & Score It"** lets you bank a glorious failure without finishing.
* Six levels: Training Room, Slippery Rooftops, Construction Chaos, Giant Fan Factory, Moving
  Platform Madness, Ultimate Flop Arena. Each has checkpoints, hazards, rings to collect and a
  finish pad. Levels unlock in order.
* Progression: medals (bronze/silver/gold per level), personal bests, 11 achievements, coins to buy
  outfits and hats, and a deterministic **Daily Stunt Challenge** (same goal for everyone each date).
* Surfaces behave differently: rubber bounces, ice is slippery, metal rings, wood and stone grip,
  soft pads absorb.

## Project layout

```
config/physics.json         All tunable character, camera, material and scoring parameters
scenes/                     main.tscn (front end), gameplay.tscn (one run)
scripts/autoload/           Config, SaveData, InputConfig, AudioManager, Progression,
                            ScoreManager, LevelManager
scripts/character/          Ragdoll (11 bodies + joints), CharacterController (balance/recovery),
                            GrabHandler, StuckGuard, SurfaceMaterials
scripts/camera/             FollowCamera (smoothing, speed-based framing, shake, wall avoidance)
scripts/levels/             LevelBase helpers + six level builders
scripts/hazards/            SwingingBeam, FanUpdraft, MovingPlatform, CrateDropper
scripts/ui/                 UiKit, MainMenu, Hud, PauseMenu, ResultsScreen, SettingsPanel
scripts/gameplay.gd         Wires a run together (checkpoints, respawn, finishing)
tests/                      Headless tests + screenshot tool
```

Tuning: edit `config/physics.json`; no code changes are needed to adjust speeds, jump height,
stun thresholds, camera feel, surface friction/bounce or scoring weights. Save data lives in
`user://save.json`.

### How the ragdoll works

The character is 11 rigid bodies joined by cone-twist (spine, neck, shoulders, hips) and hinge
(elbows, knees) joints with limits. A *balance* value from 0 (limp) to 1 (fully controlled) blends
player control with pure physics: it applies upright torque, a height spring and walking force
scaled by the body's mass. Hard impacts knock balance to zero (stun), after which a get-up phase
ramps it back. `StuckGuard` records the last safe standing spot and rescues the character if it
ends up inside geometry or wedged, so physics accidents never soft-lock a run.

## Tests

```
./run_tests.sh
```

Runs, headless: a ragdoll stability drop test; a traversal test proving launch pads, fan lifts,
the dive gap and the ledge mantle are physically possible; and a 76-check integration test
covering menus, all six levels, random-input stress (no explosions or NaNs), movement, jump, dive
and recovery, scoring, checkpoints and respawn, level completion, medals, unlocks, shop, saving
round-trips, the daily challenge, the stuck guard and pause.

To capture screenshots (needs a real renderer, e.g. under Xvfb):

```
xvfb-run -a godot --path . --rendering-method gl_compatibility res://tests/screenshot.tscn -- /some/dir
```

## Notes and limits

* Verified headlessly and with software-rendered screenshots. It has not been played with a real
  gamepad or a real audio device, so controller feel and the synthesized sound mix are untested.
* Level completability is verified per mechanic (scripted runs across each launch pad, fan, gap and
  ledge), not by a full bot playthrough of every level.
* No export presets are included (export templates must be installed through the Godot editor).
* Placeholders: all visuals are primitive shapes and procedural audio; swap real meshes or sounds
  in by assigning `AudioManager.sounds[name]` or replacing meshes in `ragdoll.gd` / level scripts.
