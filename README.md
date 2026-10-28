# Hoop Rush

A 60-second 2D basketball shooter built in Godot 4.3 with GDScript.

## Run it
1. Download Godot 4.3 (standard version) from godotengine.org.
2. Open Godot, click **Import**, and select this folder's `project.godot`.
3. Press **F5** to play.

## Controls
- **A / D** or **arrow keys**: move
- **Mouse**: aim
- **Hold left click**: charge (the meter ping-pongs, so time your release)
- **Release**: shoot
- **R** or **Space**: restart after the round

## Rules
- 2 points per make, 3 from behind the 3PT line
- Swish (no rim touch): +1
- 3 makes in a row: on fire, double points
- Each make adds 1.5 s to the clock
- At 10 points the hoop starts moving; at 25 it moves farther
- High score saves between sessions

## How it works
- Everything lives in `main.gd`: a small state machine (menu, playing, game over) drives the loop.
- Ball physics are custom: gravity, 4 substeps per frame to stop tunneling, and circle-vs-point collision on each rim edge with restitution.
- A basket counts when the ball's center crosses rim height moving downward between the rim edges.
- All graphics are drawn in code with `_draw()`, so the project needs no image assets.
- The high score is stored with `ConfigFile` in `user://`.

## Ideas to extend it
- Swap the drawn shapes for sprites and add sound effects
- Add an AnimationPlayer for the shooting motion
- Add difficulty levels or a moving defender
- Export to HTML5 and publish on itch.io
