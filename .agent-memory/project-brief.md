---
title: Project Brief
type: note
permalink: project-brief
tags:
- memory-bank
- brief
---

# Project Brief - nix-lib

## Overview

Reusable NixOS/Home Manager library for declarative system configuration. Provides standardized builders, helpers, and patterns consumed by `nix-config` and potentially other NixOS flakes.

## Core Requirements

1. **System Builders** - `mkSystem`, `mkSystems` for NixOS configurations
2. **Home Builders** - `mkHome`, `mkHomes` for Home Manager configurations
3. **Feature System** - Opt-in/opt-out feature discovery and resolution
4. **Module Utilities** - `scanModules`, `importModules`, `importIfExists`
5. **Package Utilities** - `buildPackageSet`, `discoverPackages`, overlay combinators
6. **Path Utilities** - `pathFromRoot`, `relativeToRoot` bound to consumer root

## Scope

- **In Scope**: Library functions, builders, type-safe patterns
- **Out of Scope**: Actual host/user configurations (those live in `nix-config`)

## Success Criteria

- Clean API consumed by `nix-config` without modification
- FlakeHub publishing for external consumption
- Zero breaking changes to existing consumers
- Comprehensive module scanning and discovery

## Constraints

- Must work with nixpkgs lib only (no external Nix dependencies)
- Must support `nixfmt-rfc-style` formatting
- Must pass as flake input to consumers

## Relations

- used_by [[nix-config]]