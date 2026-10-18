# Little Worlds

A small desktop idle game: five villagers, a pixel-art village, resource gathering, construction, forest expeditions, and a short mystery to uncover in one sitting.

Built with **Godot 4.3+** and **Kenney Tiny Town** (CC0). See [ASSET_CREDITS.md](ASSET_CREDITS.md).

## Requirements

- [Godot 4.3 or newer](https://godotengine.org/download) (4.7 tested in development)

## Run the game

1. Install Godot 4 and open the project folder (this directory).
2. Open `project.godot` or import the folder in the project manager.
3. Press **F5** (Play) — main scene: `scenes/main.tscn`.

From the command line (adjust the Godot binary path):

```bash
godot4 --path . res://scenes/main.tscn
```

## How to play (quick)

- Watch resources tick up while villagers wander and gather.
- Choose a **building** and click **Build** when you can afford it — structures appear on the map.
- Pick a **villager**, choose a **destination**, and click **Explore** for timed expeditions.
- Read the **history** panel for story beats; follow the shrine → river mystery, then **Offer** food when prompted.
- **Speed** and **Pause** control simulation time. Progress saves automatically to `user://little_worlds_save.json`.

Default window size is **520×620** (see `project.godot`).
