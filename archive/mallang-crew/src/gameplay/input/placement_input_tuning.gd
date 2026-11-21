## Data-driven values of design/gdd/placement-input.md section F (starting values
## and safe ranges live in that table). Loaded from
## [code]assets/data/presentation/placement_input.tres[/code].
class_name PlacementInputTuning
extends Resource

## Finger-to-piece vertical offset in cells (F1, 0.4–1.0).
@export_range(0.4, 1.0) var lift_offset_cells: float = 0.6
## Drag-start slop in px@1080 (F4, 12–32).
@export_range(12.0, 32.0) var drag_slop_px: float = 20.0
## Snap hysteresis in cells (F3, 0–0.25).
@export_range(0.0, 0.25) var snap_hysteresis_cells: float = 0.12
## Tray piece scale relative to a board cell (F6, 0.5–0.85).
@export_range(0.5, 0.85) var tray_piece_scale: float = 0.72
## Lift animation, s (0 = instant).
@export_range(0.0, 0.12) var lift_anim_s: float = 0.08
## Return-to-tray animation, s.
@export_range(0.12, 0.18) var return_anim_s: float = 0.15
## Invalid-on-board wiggle, s (0 = none).
@export_range(0.0, 0.15) var invalid_wiggle_s: float = 0.10
## Drag shadow offset, px@1080.
@export_range(6.0, 10.0) var drag_shadow_px: float = 8.0
## Commit snap to the ghost, s (rule 15).
@export_range(0.0, 0.1) var commit_snap_s: float = 0.06
## Tray slot inner margin, px@1080 (F6 m).
@export var tray_slot_margin_px: float = 12.0
