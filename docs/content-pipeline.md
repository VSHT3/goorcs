# Tower and enemy content pipeline

## One registration owner

`resources/content_catalog.tres` is the explicit, typed `ContentCatalog` registration resource. Its `towers` and `enemies` arrays are the only shipped content lists. Array order is presentation order. `CombatRules.catalog` references it; custom rules may reference another catalog.

A tower entry is a `TowerDefinition` that references its `TowerReward` identity/art resource. Collection rewards are derived from those entries, not registered separately. The match palette and both `PathBoard` renderers use the rules' catalog. Enemy send choices and inspection stats come from the accepted host snapshot; artwork comes from the same local catalog. Both peers must ship matching IDs and art. Resources are local project assets, not downloaded or sent by the host.

Host commands still validate ownership, collection access, funds, phase, and stable IDs. `MatchCombat` captures resource-defined stats on admission and publishes detached snapshots; editing a source resource does not change an admitted match. Collection saves retain their existing version and stable tower IDs. Never rename or remove an ID that is already present in a collection save without an explicit save migration.

## Add a tower using an existing attack

1. Create `resources/collection/<id>.tres` with the `TowerReward` script. Give it a unique, nonempty stable `id`, title, description, icon/atlas texture, and accent. Copy an existing atlas setup to preserve transparent-padding handling.
2. Set the reward's `board_height` (opaque height in cells) and normalized `board_anchor` (foot/base anchor). These drive drawing, shadows, and camera headroom without changing the one-cell gameplay footprint.
3. For direct projectiles, set `projectile_length` in cells and `projectile_width` in pixels. `projectile_origin` is a pixel coordinate within the icon/atlas texture; the default negative coordinate uses the ordinary centered muzzle. A second-archer variant can supply `secondary_sprite_region` and `secondary_sprite_offset`, both in that texture's pixels. The existing second-archer mechanic copies that region and offsets its second muzzle; it does not require the Arrow tower ID or original texture.
4. Create `resources/combat/towers/<id>.tres` with the `TowerDefinition` script and reference the reward. Configure positive damage, range, interval, price, base upgrade price, damage upgrade bonus, and the speed-upgrade multiplier between zero and one. `area_attack` chooses the implemented discrete neighborhood pulse instead of direct fire.
5. Reuse an existing special/evolution schema if desired: `second_archer`, direct-fire `pierce`/`bounce` choices, or area `boulders`/`onyx_ring` choices with Boulders' `freeze_runes` follow-up. Copy the corresponding shipped definition for exact fields. Those names are implemented mechanics, not content IDs. Keep the existing schema's prerequisites and mutually exclusive branches.
6. Add the **TowerDefinition** reference once to `resources/content_catalog.tres` → `towers`. Do not add another reward list, menu entry, rendering switch, RPC branch, or code constant.
7. Reimport using the [development workflow](development.md#setup), then run verification and inspect the actual game. With an isolated collection save, unlock the new reward through a chest, buy it from the palette, inspect it, purchase its upgrades, and observe its attacks. Check both board orientations and separate host/client processes. Commit authored resources and Godot-generated script UID sidecars, not import caches.

Existing saved players keep their unlocks and see the added tower as locked until awarded. Chest exhaustion and reward-count capping automatically include the new entry.

## Add an enemy using existing movement and damage

1. Create `resources/combat/enemies/<id>.tres` with the `EnemyDefinition` script. Give it a unique, nonempty stable `id`, title, description, texture, source-facing flag, board height, and normalized foot anchor.
2. Configure positive health/speed multipliers, base damage, spawn weight, introduction wave, and send cost; income/count-cap/count growth must be nonnegative. `count_cap_growth_interval` is positive; `max_weight_share` is finite in `[0, 1]`. A zero count cap means unlimited. Finite caps grow relative to `first_wave`; share limits cap weight, not head count, and are floored for each wave budget.
3. Add the definition once to `resources/content_catalog.tres` → `enemies`. This registers send choices, regular-wave eligibility, type previews, enemy inspection, sprite/facing/slow presentation, and host-accepted instances. No enemy-name switch or RPC edit is needed.
4. Keep at least one always-unlocked (`first_wave = 1`), weight-one, unlimited-count, full-share (`max_weight_share = 1.0`) enemy so every wave can exactly fill its remaining budget. It may have any ID; Grunt is only the shipped choice. An added expensive type can legitimately be absent until the budget and its floored share allowance fit it. Paid sends ignore regular unlock/count/share constraints, as before.
5. Run verification and graphical smoke via the [development workflow](development.md#setup). Exercise dropdown selection and paid sends during planning and combat, regular-wave appearance at eligible rounds, count/share limits, movement/facing, damaged health bars, inspection, leaks, both board orientations, and separate host/client agreement.

## Validation and injected catalogs

`ContentCatalog.validation_errors()` returns actionable messages without logging or mutating the resources. It rejects null definitions, missing tower rewards, empty/duplicate IDs within each content kind, missing titles, invalid/nonfinite combat/economy/wave values, unsupported special/evolution schemas, and invalid/nonfinite presentation geometry. A null texture is permitted for non-rendered rule fixtures; authored playable content must supply textures. The normal renderer does not invent artwork for unknown IDs.

`CollectionStore` validates the catalog before loading or granting rewards and exposes errors without replacing an existing save. `MatchCombat` rejects an invalid catalog and requires the exact-fill remainder-enemy invariant before starting combat. Invalid configuration must be fixed, not silently replaced with shipped defaults. A custom collection-only test catalog can have no enemies; an actual combat catalog cannot.

For tests or a custom match, assign `rules.catalog` before instantiating the game/model. Pass that same resource to `CollectionStore.new(save_path, rules.catalog, random)` when injecting a store. `store.catalog` is its derived reward array, while `store.content_catalog` is the owning resource. `CombatRules.new()` owns detached registration arrays, but definitions are shared: duplicate a definition (and its reward when editing identity/art) before tuning it. There are no legacy parallel-list overrides.

`tests/content_catalog_test.gd` exercises a catalog containing no shipped IDs through saved chest unlocks, actual main-scene UI, mirrored authoritative purchases and sends, exact-fill waves, accepted snapshots, renderer artwork lookup, and both second-archer muzzle origins. Existing combat, collection, palette, and rendered board regressions retain their behavioral coverage.

## Existing behavior versus novel mechanics

Resources can change stats, identity, existing artwork/geometry, wave/send tuning, and select the already implemented attacks/evolutions above. They do not implement arbitrary behavior. A new damage/status model, targeting policy, projectile impact rule, movement/routing rule, upgrade branch, footprint, or evolution needs code in its existing rule owner, matching presentation, host snapshot/command handling where relevant, and behavioral regressions. Do not advertise a novel mechanic only in a resource description or add an ID-specific exception to imitate it.

## Cutover verification

The complete project check passed all 31 suites plus five engine/import/isolation/startup gates. A separate graphical main-scene smoke saved and reloaded a catalog with additional tower/enemy IDs, unlocked the tower through real chest grants, bought and upgraded it through the actual palette/management UI to level IV, selected and sent the enemy, and observed host attacks. Captures showed the added palette entry, enemy selection, and both archer sprites. Temporary variants and smoke scripts were not shipped; existing balance resources were unchanged.
