## Shared helpers for the tray supply tests (tray-supply AC preamble): the real MVP
## registry, config builders, a stable text form of tray contents and the
## committed golden files under [code]tests/fixtures/tray/[/code].
class_name TrayFixture
extends RefCounted

const REGISTRY_PATH := "res://assets/data/crew/crew_registry.tres"
const TRAY_RULES_PATH := "res://assets/data/rules/tray_rules.tres"
const GOLDEN_DIR := "res://tests/fixtures/tray/"
const BOARD_DIR := "res://tests/fixtures/boards/"
## Starter team (crew-definition rule 14).
const DEFAULT_TEAM: Array[StringName] = [&"nyangi", &"gomgom", &"piyak"]
## Text form of an empty slot.
const EMPTY_SLOT := "-"


## The real MVP registry, validated.
static func registry() -> CrewRegistry:
	var r: CrewRegistry = load(REGISTRY_PATH)
	r.load_and_validate()
	return r


## A fresh copy of the committed tray rules (tests may change fields).
static func cfg() -> TrayRules:
	var base: TrayRules = load(TRAY_RULES_PATH)
	return base.duplicate()


## A typed team from ids.
static func team(ids: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in ids:
		out.append(StringName(id))
	return out


## "SHAPE:crew:face" ("SHAPE::-1" for a faceless piece) or [constant EMPTY_SLOT].
static func describe(piece: Variant) -> String:
	if piece == null:
		return EMPTY_SLOT
	var p: PieceInstance = piece
	return "%s:%s:%d" % [p.shape.id, p.crew_id, p.face_index]


## Text form of every slot of [param state].
static func describe_slots(state: TrayState) -> Array:
	var out := []
	for p: Variant in state.slots:
		out.append(describe(p))
	return out


## Runs [param n] refills on [param board] (empty 8×8 when null), consuming every
## slot after each; returns the trays as text and the TRAY_RESCUED records.
static func play(team_ids: Array[StringName], config: TrayRules, stage_seed: int, n: int, board: BoardState = null) -> Dictionary:
	var b := board if board != null else BoardFixture.empty()
	var state := TraySupplyRules.init_state(team_ids, config, stage_seed, registry())
	var trays := []
	var rescued := []
	for i: int in n:
		var r := TraySupplyRules.refill(state, b, TraySupplyRules.BUDGET_UNLIMITED)
		trays.append(describe_slots(r.state))
		rescued.append_array(r.rescued)
		state = _consume_all(r.state)
	return {&"trays": trays, &"rescued": rescued, &"state": state}


## Empties every occupied slot.
static func _consume_all(state: TrayState) -> TrayState:
	var s := state
	for x: int in s.slots.size():
		if s.slots[x] != null:
			s = TraySupplyRules.consume(s, x)
	return s


## Public form of [method _consume_all].
static func consume_all(state: TrayState) -> TrayState:
	return _consume_all(state)


## Parsed golden file [param file_name] (JSON).
static func golden(file_name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_DIR + file_name))


## Board from [code]tests/fixtures/boards/<file_name>[/code].
static func board(file_name: String) -> BoardState:
	return BoardFixture.board_file(BOARD_DIR + file_name)


## An in-memory crew with one shape (tests only — AC-08).
static func test_crew(id: StringName, offsets: Array, face_cell: int = -1) -> CrewDef:
	var c := CrewDef.new()
	c.id = id
	var e := CrewShapeEntry.new()
	e.shape = PieceShape.make(StringName("%s_shape" % id), offsets)
	e.face_cell = face_cell
	var entries: Array[CrewShapeEntry] = [e]
	c.shapes = entries
	return c


## A registry holding only [param crews] (not validated — tray reads shapes only).
static func registry_of(crews: Array) -> CrewRegistry:
	var r := CrewRegistry.new()
	var typed: Array[CrewDef] = []
	for c: CrewDef in crews:
		typed.append(c)
	r.crews = typed
	return r
