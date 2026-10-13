# Goorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Playable local path workshop plus a persistent tower collection and animated reward chests, reached through the main menu. Combat, multiplayer, loadouts, permanent stat growth, and final art are not implemented. No MCP plugin is installed.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

## Collection and chests

- Choose **Collection & chests**, then **Open free chest**. The chest shakes, opens with light and decorative coins, and reveals the actual rewards together. There is no roulette reel.
- Unlock Arrow tower, Orc ballista, and Rune obelisk. These are collection identities with original icons, not implemented combat units.
- The ballista's base icon is the accepted PixelLab crossbow-tower sprite, imported unchanged. Arrow tower and Rune obelisk still use procedural icons.
- The orc chest uses cleaned user-supplied PixelLab sprites. Its lid transitions between closed/open poses; light and coin effects remain native Godot effects. Sound is not implemented yet.
- Provisional reward-count odds are 80% for one, 15% for three, and 5% for five. Draws contain only locked types and are capped to those remaining; the three-type roster cannot grant five actual rewards.
- **Skip reveal** changes only the animation. Rewards are saved before it starts; leaving and returning cannot reroll or grant them again.
- Unlock all three types to complete the collection; further openings are disabled.
- **Reset progress** clears all saved collection unlocks after confirmation, so you can open chests again. It also clears the previous reward display, but leaves the workshop layout unchanged.
- Collection unlocks survive restarting on this computer. Workshop layouts still last only for the running session. See [save ownership and verification](docs/development.md#collection-and-chest-verification).

## Path workshop

- Choose **Open workshop** from the main menu. **Menu / Esc** returns to it; **Resume workshop** or Esc resumes without clearing tiles.
- Menu navigation preserves the layout only for this session. **Quit** exits; layouts are not saved after quitting.
- Left click or drag to place tiles; right click or drag to remove them. **Clear placed tiles** resets the board.
- Only shared edges connect. Entrance and base are fixed and do not spend budget.
- Unused budget is allowed. A ready layout connects the base and every placed tile to the entrance.
- The green line previews the shortest route, not placement order. Branches and adjacent sections can create shortcuts.
- The 14×9 board, opposite-side endpoints, and 30-tile maximum are provisional. Adjust the main scene's exported settings together in the Inspector.

This workshop does not simulate waves, enemies, or combat-time route locking.

## Documentation

- [Game brief (PDF)](docs/goorcs-brief.pdf): a three-page introduction for friends, with [editable source](docs/goorcs-brief.typ).
- [Agent instructions](AGENTS.md): required reading, editing rules, state ownership, and completion criteria.
- [Game direction](docs/game-direction.md): intended experience, technical decisions, and first playable milestone.
- [Development workflow](docs/development.md): setup, verification, and optional MCP tooling.

## Layout

```text
project.godot       Engine settings and main scene
AGENTS.md          Repository editing instructions
scenes/            Main navigation, path workshop, collection, and reusable chest reveal
scripts/           Rule owners, persistence, input, and presentation
resources/collection/  Tower reward definitions
assets/            Imported chest and base ballista sprites
tests/             Path, navigation, collection, and chest regressions
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
