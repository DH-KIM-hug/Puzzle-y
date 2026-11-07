# Technical Preferences

<!-- project.yaml at the repo root is the machine-readable source of truth for
     engine, specialists, naming, performance, platform, and testing.framework.
     This file is the human-readable LEGACY FALLBACK: agents and skills resolve
     each key from project.yaml first and fall back here only when the
     project.yaml key is absent. /setup-engine dual-writes both.
     Forbidden patterns and allowed libraries are NOT migrated — they live only
     in this file. Populated by /setup-engine; updated as decisions are made. -->

## Engine & Language

- **Engine**: Godot 4.7
- **Language**: GDScript
- **Rendering**: Compatibility (2D mobile)
- **Physics**: Godot Physics 2D

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Mobile (Android first, iOS later)
- **Input Methods**: Touch (mouse emulates touch in editor)
- **Primary Input**: Touch (swipe to swap, tap crew icon to fire skill)
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: Portrait 720x1280 base; touch targets >= ~64px at 1080p; safe-area/notch handling; pause the 60s timer when the app is backgrounded.

## Naming Conventions

- **Classes**: PascalCase (e.g., `CrewMember`)
- **Variables**: snake_case (e.g., `gauge_value`)
- **Signals/Events**: snake_case past tense (e.g., `skill_fired`)
- **Files**: snake_case matching class (e.g., `crew_member.gd`)
- **Scenes/Prefabs**: snake_case matching the file (e.g., `crew_member.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_GAUGE`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.67 ms
- **Draw Calls**: [TO BE CONFIGURED]
- **Memory Ceiling**: [TO BE CONFIGURED]

## Testing

- **Framework**: gdUnit4 (install via /test-setup)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing, and idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only for native extensions.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (primary language) | godot-gdscript-specialist |
| Shader / material files | godot-shader-specialist |
| UI / screen files | godot-specialist |
| Scene / prefab / level files | godot-specialist |
| Native extension / plugin files | godot-gdextension-specialist |
| General architecture review | Primary |
