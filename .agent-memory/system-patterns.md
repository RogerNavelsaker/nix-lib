---
title: System Patterns
type: note
permalink: system-patterns
tags:
- memory-bank
- patterns
---

# System Patterns - nix-lib

## Architecture

```
flake.nix
  └── lib/
      ├── default.nix      # Entry point, mkLib constructor
      ├── builders.nix     # mkSystem, mkHome, mkSystems, mkHomes
      ├── features.nix     # Feature discovery and resolution
      ├── modules.nix      # Module scanning utilities
      ├── packages.nix     # Package discovery and overlays
      ├── paths.nix        # Path utilities bound to root
      ├── overlays.nix     # Overlay combinators
      └── impermanence.nix # Impermanence helpers (stub)
```

## Key Patterns

### 1. Root-Bound Paths

All path utilities receive consumer's `root` and return functions that resolve relative to it:

```nix
paths = import ./paths.nix { inherit lib root; };
pathFromRoot = paths.pathFromRoot;
# pathFromRoot "hosts" → /path/to/consumer/hosts
```

### 2. Feature System

Three-tier feature organization:
- `default/` - Always enabled
- `opt-in/` - Disabled by default, consumer explicitly enables
- `opt-out/` - Enabled by default, consumer explicitly disables

Pattern matching supports nested features: `"gui"` matches `"gui"`, `"gui/hyprland"`, etc.

### 3. specialArgs Injection

`nix-lib` attrset passed to all NixOS and Home Manager modules:

```nix
specialArgs = {
  inputs = <inputs without self>;
  nix-lib = {
    scanModules, importModules, importIfExists,
    features, pathFromRoot, buildPackageSet, ...
  };
};
```

### 4. SOPS Integration

When `secrets` path provided:
- Auto-configures user passwords from `secrets/users/{user}/secrets.yaml`
- Auto-configures SSH keys for Home Manager

### 5. Overlay Composition

`combineOverlays` merges:
1. Consumer's `overlays/default.nix` exports
2. Custom overlays passed to builder

### 6. User Config Loading

`mkHomeModules` imports user configs in order:
1. `users/{username}/default.nix` - Shared user config (if exists)
2. `users/{username}/{hostname}.nix` - Host-specific config (if exists)

This enables:
- NixOS + integrated HM: uses `users/{user}/{hostname}.nix` via NixOS module
- NixOS + standalone HM: same pattern via `mkHome`
- Non-NixOS + standalone HM: same pattern (e.g., Arch Linux with home-manager)

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| No self in inputs | Prevents circular dependencies |
| Separate mkSystem/mkHome | Different specialArgs requirements |
| Feature directories | Filesystem = declaration of available features |
| Configurable paths | Consumers may use different directory names |