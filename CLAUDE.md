# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ResizeAlign is a Roblox Studio plugin which allows the user to click two faces of parts in 3D space, and have the plugin resize/extend those parts so the faces meet. Seven resize modes are supported: OuterTouch, InnerTouch, WedgeJoin, RoundedJoin, ButtJoint, ExtendUpTo, and ExtendInto.
It outputs a `.rbxmx` plugin file built via Rojo.

## Build Commands

```bash
# Build the plugin to the plugins directory (default build task)
# DO NOT build using rojo build -o. -p was added recently for plugins and is what we need.
rojo build -p "ResizeAlign V2.0.rbxmx"

# Run tests (*.spec.lua files in the Src folder)
python runtests.py

# Install dependencies
wally install
```

Tools are managed via Aftman (`aftman.toml`): Rojo 7.6.1. Dependencies are managed via Wally (`wally.toml`).

## Architecture

Three-layer design:

1. **Functionality layer** — Face selection, raycasting, resize geometry.
   - `src/createResizeAlignSession.lua` — Session lifecycle: face selection FSM (FaceA → FaceB), input handling via UserInputService, edge-threshold smart face detection, DraggerHandler for Ctrl+click mode.
   - `src/doExtend.lua` — Core resize algorithm: computes how to resize two parts so their selected faces meet according to the chosen mode. Integrates with ChangeHistoryService and JointMaker.
   - `src/FaceHighlight.lua` — React component rendering face adornments (BoxHandleAdornment + CylinderHandleAdornments) for hover/selected faces.
   - `src/copyPartProps.lua` — Copies physical/visual properties when creating new parts (used by RoundedJoin fill).
   - `src/TestTypes.lua` — Types definition of the testing framework, spec files take in a type from here.

2. **Settings layer** — Persistent configuration that the functionality layer reads.
   - `src/Settings.lua` — Reads/writes plugin settings (key: `"resizeAlignState"`), exposes ResizeMode, SelectionThreshold, and ClassicUI options.

3. **UI layer** — React components that modify settings and trigger operations.
   - `src/ResizeAlignGui.lua` — Main settings panel (React) with modern (ChipForToggle) and classic (OperationButton) UI modes. Includes AdornmentOverlay that portals face highlights to CoreGui.
   - `src/PluginGui/` — Reusable UI components (NumberInput, Vector3Input, Checkbox, ChipToggle, SubPanel, etc.).

**Entry point:** `loader.server.lua` creates the toolbar button and dock widget, then lazy-loads `src/main.lua` on first activation. `src/main.lua` orchestrates the three layers — it manages the active session, and mounts the React UI.

## Key Conventions

- All source files use `--!strict` (Luau strict type checking) and many use `--!native` (native codegen).
- Types are defined with `export type` and collected in `src/PluginGui/Types.lua` for UI-related types.
- React components use `React.createElement` (aliased as `e`) — not JSX.
- The Signal library (`Packages.Signal`) is used for custom events throughout.
- Modules typically `return` a single function (e.g., `createResizeAlignSession`, `doExtend`) rather than a table of exports.
- Undo/redo integrates with `ChangeHistoryService` using recording-based waypoints (`TryBeginRecording`/`FinishRecording`).

## Dependencies (via Wally)

- **React / ReactRoblox** — UI framework
- **DraggerFramework** — 3D handle/manipulator system (authored by stravant)
- **DraggerHandler** — Simple wrapper around DraggerFramework to activate a basic dragger tool that can move selected objects.
- **Signal (GoodSignal)** — Event system
- **Geometry** — Geometric utility library
- **createSharedToolbar** — Optional toolbar combining with other plugins
