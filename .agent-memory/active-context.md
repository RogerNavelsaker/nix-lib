---
title: Active Context
type: note
permalink: active-context
tags:
- memory-bank
- active
---

# Active Context - nix-lib

## Current Focus

mkHome now supports hostname-specific user configs for standalone home-manager.

## Recent Changes (Sliding Window)

1. **bf5c07e** - mkHomeModules imports users/{username}/{hostname}.nix for standalone HM
2. **2025-12-16** - Memory bank migrated from main project, flat structure
3. **2025-12-16** - Memory bank initialized
4. **ccaa7f8** - FlakeHub integration merged (PR #1)
5. **8f53d7e** - FlakeHub workflow added
6. **f9cb76b** - Renamed `homeDir` to `usersDir` for consistency
7. **46baf7c** - Fixed specialArgs to reference `nix-lib` not `nix-config`
8. **e2ae195** - Fixed packages.nix to use `customPaths` argument
9. **c5f6e33** - Fixed infinite recursion in overlays/pkgsFor
10. **fd9a81f** - Initial commit

## Active Decisions

- FlakeHub used for input URLs (nixpkgs, systems)
- Using `usersDir` terminology (not `homeDir`)
- `nix-lib` attrset passed via `specialArgs` to all modules

## Open Questions

None currently.

## Next Actions

- Monitor consumer (`nix-config`) for integration issues
- Consider adding impermanence helpers
- Document public API