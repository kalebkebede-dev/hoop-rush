# Hoop Rush 🏀

A 60-second basketball shooting game made in Godot 4.3 with GDScript.

**Play it here:** https://kalebkebede-dev.github.io/hoop-rush/ (desktop, mouse + keyboard)

![Hoop Rush gameplay](docs/gameplay.png)

## What it is

I play a lot of pickup ball, so I wanted my first Godot project to be a basketball game. You get 60 seconds to score as much as you can. You move along the baseline, aim with the mouse, and hold click to charge your shot. The power meter goes up and back down, so the timing of your release actually matters.

Scoring:
- 2 points for a normal make, 3 from behind the line
- +1 for a swish (no rim)
- 3 makes in a row puts you "on fire" for double points
- every make adds 1.5 seconds to the clock
- once you hit 10 points the hoop starts moving, and it moves farther at 25

Your high score saves between games.

## Controls

- A / D or arrow keys: move
- Mouse: aim
- Hold left click: charge, release to shoot
- R or Space: play again

## How it works

Everything is in `main.gd`. A few parts I think are interesting:

- **Ball physics.** Instead of using Godot's physics engine, the ball uses its own gravity and velocity. Each frame is split into 4 substeps, because without that, fast shots could skip right through the rim.
- **Rim collisions.** Each side of the rim is treated as a small circle. When the ball hits one, it bounces off along the collision normal and loses some speed, which is what gives you those shots that roll around the rim.
- **Detecting a make.** A basket only counts if the center of the ball crosses rim height while moving down and lands between the two rim edges. If the ball never touched the rim on the way, it's a swish.
- **No art files.** The court, player, hoop and ball are all drawn with `_draw()`, so the whole game is just code.

## Running it yourself

1. Download Godot 4.3
2. Import `project.godot`
3. Press F5

The browser version in `docs/` comes from the included Web export preset. Threads are turned off so it works on GitHub Pages.

## What I want to add next

- [ ] Sound effects (swish, rim, buzzer)
- [ ] Sprites and a real shooting animation
- [ ] A defender that contests shots
- [ ] Touch controls for phones

## License

MIT
