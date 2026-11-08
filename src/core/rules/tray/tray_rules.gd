## Tray supply data (design/gdd/tray-supply.md rule F table, rules 11, 13, 18–22).
## Global values ([member tray_size], [member crew_bag_copies]) live in
## [code]assets/data/rules/tray_rules.tres[/code]; the stage fields are copied in by
## stage data (Stage & Goals GDD, provisional) — this resource is their schema.
## Integer-only: shares are per-mille (ADR-0001 "no float in the Rules Core").
class_name TrayRules
extends Resource

## Seed policy (rule 18).
enum SeedMode { FIXED, PER_ATTEMPT }
## What follows an exhausted [member tray_script] (rule 20).
enum AfterScript { GENERATE, LOOP }

## Tray slots (rule 1). Safe range 2–4.
@export var tray_size: int = 3
## Crew-bag tokens per crew (rule 8, F1). Safe range 1–3.
@export var crew_bag_copies: int = 1
## Minimal pre-reveal rescue in generated mode (rule 13).
@export var rescue_enabled: bool = true
## Stage allows faceless pieces (board-rules rule 5).
@export var allow_faceless_pieces: bool = false
## Chance per generated piece to be faceless, per mille (rule 11). 0–1000;
## ignored (lint warning) unless [member allow_faceless_pieces].
@export_range(0, 1000) var faceless_share_permille: int = 0
## Seed policy; [constant SeedMode.FIXED] is the MVP default (rule 18).
@export var tray_seed_mode: SeedMode = SeedMode.FIXED
## Scripted trays, one entry per refill (rule 19). Entry = Array of piece specs,
## spec = Dictionary {&"shape": shape id or &"*", &"crew": team_slot int |
## crew id StringName | null (faceless), &"face": int (-1 = RNG) | null (faceless)}.
## Missing [code]crew[/code] = null, missing [code]face[/code] = -1.
@export var tray_script: Array = []
## Supply after the script runs out (rule 20).
@export var after_script: AfterScript = AfterScript.GENERATE
## Stage fixes the team, so scripts may name crew ids directly (rule 22, Q7 provisional).
@export var team_fixed: bool = false
## Extra catalog shapes a script may name besides the registry's (rule 22).
@export var extra_shapes: Array[PieceShape] = []
## Balance alert line for the rescue rate ρ, per mille (F6). Metric only — no runtime effect.
@export_range(20, 250) var rescue_rate_alert_permille: int = 100
