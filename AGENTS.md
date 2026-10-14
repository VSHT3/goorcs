# Agent instructions

Gorcs is a private, desktop-first 2D tower-defense game for friends. Development is primarily agent implementation plus human playtesting.

## Read before editing

- [README.md](README.md): current implementation status and project layout. A planned feature is not an existing system.
- [Game direction](docs/game-direction.md): intended experience, first playable milestone, proposed architecture, and unresolved decisions.
- [Development workflow](docs/development.md): required engine release, exact run/check commands, verification limits, and optional tooling.

Read all three for the first task in a session. Add area-specific guidance only when an implemented subsystem needs it; link it here rather than expanding this file into a full design document.

For sprite generation, editing, or export, see the [AI-to-sprite pipeline](docs/sprite-pipeline.md).

A single commit with a lot of work is acceptable. No need to produce multiple hunks or stuff, just a singular commit for convenience.

## Sources of truth

- Engine release and executable commands: `docs/development.md`. Reference them elsewhere instead of copying version numbers or command lists.
- Runtime settings and main scene: `project.godot`. Formatting and generated-file rules: `.editorconfig`, `.gitattributes`, and `.gitignore`.
- Existing behavior: source and observed runtime results. If documentation disagrees, resolve the discrepancy; do not silently treat a proposal as implemented.

## Implementation conventions

- Use typed GDScript and ordinary Godot scenes/resources. Prefer existing engine capabilities; do not introduce a custom framework without a concrete need.
- Keep gameplay rules and data separate from UI and visual effects. Reuse a rule's owner rather than reimplementing it in another caller.
- Give mutable state one clear owner. UI selection and camera state must not become alternate copies of match state.
- Preserve unsaved editor work and unrelated changes. Coordinate external file edits with editor saves.
- Commit source resources and Godot UID sidecars; keep generated caches, builds, and credentials out of Git.
- Keep changes small and playable. Do not build extensive progression before proving the two-player core loop.

## Match state ownership

Match planning and combat use host-authoritative state. These ownership constraints also apply to future currency and reward systems; changing that design requires an explicit decision first.

- The host owns currency, enemy state, damage, and gameplay reward rolls. Independent client calculations must not decide authoritative outcomes.
- Players submit commands; the host validates and applies them. Host-player actions use the same rules as remote-player actions.
- A purchase and its gameplay effect succeed or fail together, so a rejected action cannot spend currency or create a free enemy.
- Camera, selection, and cosmetic effects stay local and cannot change match outcomes.

## Verification and completion

- Run the applicable commands in `docs/development.md`; inspect errors as well as exit status. Do not claim a check that was not run.
- Exercise changed gameplay in the running game. For visual or input changes, inspect the actual surface; headless success is not visual proof. If display access is unavailable, state that limit.
- Verify networking with separate host/client processes and their resulting state. Internet support requires separate machines and networks, not just localhost.
- Add regression tests for plausible behavior failures as systems arrive. Do not add tests that only pin source text, UI wording, or incidental defaults.
- Record significant decisions as rule, reason, and how to check them. Keep current-state docs accurate; grow deeper documentation only where needed.
- Commit a coherent, verified change using an imperative Conventional Commit subject. Push only when requested or included in the agreed task.

## Scope boundaries

- Do not add public matchmaking, accounts, monetization, paid services, or MCP plugins without an explicit project decision.
- MCP/editor bridges are optional development tooling, not a runtime dependency for players. Keep editor-control access separate from game networking and out of distributed builds.
- Follow the first playable milestone before expanding scope. Ask about materially different product choices; use project conventions for routine implementation decisions.
