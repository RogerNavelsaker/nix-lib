---
title: Tech Context
type: note
permalink: tech-context
tags:
- memory-bank
- tech
---

# Tech Context - nix-lib

## Stack

| Component | Technology |
|-----------|------------|
| Language | Nix |
| Framework | Nix Flakes |
| Inputs | nixpkgs (FlakeHub), nix-systems (FlakeHub) |
| Formatter | nixfmt-rfc-style |
| CI/CD | GitHub Actions (FlakeHub publish) |

## Directory Structure

```
.
├── flake.nix          # Flake entry point
├── flake.lock         # Locked inputs
├── lib/               # Library implementation
│   ├── default.nix    # mkLib constructor
│   ├── builders.nix   # System/Home builders
│   ├── features.nix   # Feature system
│   ├── modules.nix    # Module utilities
│   ├── packages.nix   # Package utilities
│   ├── paths.nix      # Path helpers
│   ├── overlays.nix   # Overlay utilities
│   └── impermanence.nix
└── .github/
    └── workflows/
        └── flakehub.yml
```

## Dependencies

### Flake Inputs (Locked)

- `nixpkgs` - NixOS/nixpkgs via FlakeHub
- `systems` - nix-systems/default-linux via FlakeHub

### Consumer Expected Inputs

When consumed, expects these in consumer's inputs:
- `home-manager` (for mkHome, integrated HM mode)
- `sops-nix` (for secrets integration)
- `systems` (for forEachSystem)

## Development Setup

```bash
nix develop  # Enter devshell
nix fmt      # Format with nixfmt-rfc-style
```

## Constraints

- Pure Nix evaluation (no IFD)
- Must work as flake input only
- No runtime dependencies
- Consumer provides all actual configuration inputs

## Flake Outputs

```nix
{
  lib = import ./lib { inherit (nixpkgs) lib; };
  formatter.<system> = nixfmt-rfc-style;
}
```