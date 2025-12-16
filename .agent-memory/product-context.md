---
title: Product Context
type: note
permalink: product-context
tags:
- memory-bank
- context
---

# Product Context - nix-lib

## Why This Exists

NixOS configurations often duplicate boilerplate: system builders, Home Manager integration, feature toggles, module scanning. This library extracts those patterns into a reusable flake input.

## Problems Solved

1. **DRY Violation** - Same builder logic copied across flakes
2. **Inconsistent Patterns** - Different approaches to features, modules, overlays
3. **Complex Integration** - Home Manager + SOPS + overlays require coordination
4. **Discovery Friction** - Manual module/package enumeration

## How It Works

Consumer calls `mkLib` with their `inputs` and `root`:

```nix
lib = nix-lib.lib.mkLib {
  inherit inputs;
  root = ./.;
};
```

This returns bound helpers that understand the consumer's directory structure.

## User Experience Goals

- **Zero Config** - Sensible defaults for directory names
- **Customizable** - Override any path (`hostsDir`, `usersDir`, etc.)
- **Transparent** - `nix-lib` passed to all modules via `specialArgs`
- **Feature Ergonomics** - Simple `opt-in`/`opt-out` lists

## Key Workflows

1. **Define Host** - `lib.mkSystem { hostname = "foo"; users = ["bar"]; }`
2. **Define User** - `lib.mkHome { username = "bar"; hostname = "foo"; }`
3. **Enable Feature** - `features.opt-in = ["gui/hyprland"];`
4. **Scan Modules** - `lib.scanModules ./modules`