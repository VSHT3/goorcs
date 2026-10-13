# Goorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Playable local path-building prototype: place/remove square-grid path tiles, track a maximum budget, validate connectivity, and preview the shortest entrance-to-base route. Combat, multiplayer, progression, and final art are not implemented. No MCP plugin is installed.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

## Path workshop

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
scenes/main.tscn    Playable path workshop
scripts/           Path rules, board drawing/input, and UI controller
tests/             Headless path-rule regressions
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
