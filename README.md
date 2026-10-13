# Goorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Minimal Godot initialization only: a runnable title scene and project documentation. Gameplay, multiplayer, progression, and assets have not been implemented. No MCP plugin is installed.

## Run

Use the standard Godot edition and the [required engine release](docs/development.md#setup). Import `project.godot` into Godot and press **F5** to run the project.

For command-line launch and verification, see the [development commands](docs/development.md#setup).

## Documentation

- [Agent instructions](AGENTS.md): required reading, editing rules, state ownership, and completion criteria.
- [Game direction](docs/game-direction.md): intended experience, technical decisions, and first playable milestone.
- [Development workflow](docs/development.md): setup, verification, and optional MCP tooling.

## Layout

```text
project.godot       Engine settings and main scene
AGENTS.md          Repository editing instructions
scenes/main.tscn    Initial title scene
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
