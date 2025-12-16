---
title: Changelog
type: note
permalink: changelog
tags:
- memory-bank
- changelog
---

# Changelog - nix-lib

All notable changes to this project.

## [Unreleased]

### Added
- Memory bank initialization

## [0.1.0] - 2025-12

### Added
- `mkLib` constructor for creating bound library instance
- `mkSystem` / `mkSystems` for NixOS configuration building
- `mkHome` / `mkHomes` for Home Manager configuration building
- Feature system with default/opt-in/opt-out tiers
- Module utilities: `scanModules`, `importModules`, `importIfExists`
- Package utilities: `buildPackageSet`, `discoverPackages`
- Overlay composition with `combineOverlays`
- Path utilities: `pathFromRoot`, `relativeToRoot`
- SOPS integration for user passwords and SSH keys
- FlakeHub publishing workflow
- `nix-lib` specialArgs injection to all modules

### Changed
- Renamed `homeDir` to `usersDir` for consistency
- Fixed specialArgs to reference `nix-lib` (not `nix-config`)

### Fixed
- `packages.nix` now uses `customPaths` argument correctly
- Resolved infinite recursion in `overlays`/`pkgsFor`

---

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).