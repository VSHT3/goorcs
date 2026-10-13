# Goorcs

A private, desktop-first 2D tower-defense game for friends, developed with AI assistance.

## Current state

Minimal Godot initialization only: a runnable title scene and project documentation. Gameplay, multiplayer, progression, and assets have not been implemented. No MCP plugin is installed.

## Run

Use **Godot 4.7.2 stable, standard edition** (not the .NET edition). Import `project.godot` into Godot and press **F6** to run the open scene, or **F5** to run the project.

With the Godot executable available as `godot` on your PATH:

```sh
godot --editor --path .
godot --path .
```

## Documentation

- [Game direction](docs/game-direction.md): intended experience, technical decisions, and first playable milestone.
- [Development workflow](docs/development.md): setup, agent conventions, verification, and optional MCP tooling.

## Layout

```text
project.godot       Engine settings and main scene
scenes/main.tscn    Initial title scene
docs/              Project documentation
```

This repository is private. No public release or open-source license is currently planned.
