# MUTATE! Steal & Fuse

Roblox tycoon where every creature is unique: buy base species, fuse any two into a
procedurally generated hybrid (name, color, stats), and steal rivals' creatures when
their base lock expires. Built on the proven steal-tycoon loop with a fusion-breeding
core that no incumbent has.

## Core loop

1. Buy creatures from the central conveyor (7 rarity tiers).
2. Creatures earn cash per second while parked on your plot.
3. Fuse two creatures in the Fusion Lab: the hybrid's income, name, and colors are
   computed from both parents (weighted average x rarity multiplier x mutation roll).
4. Lock your base for 45s; after it expires there is a 60s raid window.
5. Grab a creature from an open base and carry it back to your pad to secure it.
6. Rebirth: reset everything for +25% permanent income multiplier and 8 more slots.

Mutations (Neon x1.5, Cosmic x3, Void x6) can drop on any fusion. Every roster is
unique, which drives screenshot sharing and long-tail content without new assets.

## Repository layout

```
src/shared/     ReplicatedStorage.Shared: config, pure logic (fusion math, economy math)
src/server/     ServerScriptService: bootstrap + services (Data, Economy, Creature,
                Fusion, Theft, Base, Remotes)
src/client/     StarterPlayerScripts: bootstrap + controllers (Network, UI)
tests/          lune-run headless specs + syntax checker
```

Architecture: two-phase Init/Start service lifecycle, explicit dependency wiring from
the bootstrap (no circular requires), server-authoritative economy, data-driven tuning
via `src/shared/Config/GameConfig.luau`.

## Toolchain

- Rojo (`default.project.json`) to sync into Studio
- [lune](https://lune-org.github.io) for headless tests

## Commands

```sh
lune run tests/run_tests.luau      # unit tests (pure logic modules)
lune run tests/syntax_check.luau   # compile-check every source file
rojo serve                         # live-sync into Roblox Studio
```

## Design notes

- All money movement is server-side; remotes validate types, distance, lock state,
  and carry limits before mutating anything.
- Pure logic (FusionMath, EconomyMath, NameGenerator, RNG) has zero Roblox-instance
  dependencies so it runs headless under lune; FusionMath accepts injected deps for
  tests and self-resolves requires in-game.
