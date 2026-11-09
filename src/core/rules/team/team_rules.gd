## Team composition rules (design/gdd/team-composition.md rules 1–13, F1–F3) as
## pure static functions over a [TeamRule], the [CrewRegistry] and an
## [OwnedCrews] provider. No UI, no save I/O: memories come in and go out as
## [TeamMemory] values.
## [codeblock]
## var team := TeamRules.resolve_default_team(stage.effective_team_rule(), registry, owned, memory, stage.id)
## if TeamRules.check_team(team, rule, registry, owned) == TeamRules.Reason.OK:
##     memory = TeamRules.remember(memory, stage.id, team, rule, owned)
##     flow.start(stage, team)
## [/codeblock]
##
## Spec ambiguities resolved here (logged per task brief):
## [br]- F2 lists [code]starter_ids()[/code] (whose implementation sorts by text) but
##   rule 9 says the first default team is in *registry order*; registry order is used.
## [br]- F1 condition 4 "c ∈ L_S": a non-owned crew is allowed when it is locked in
##   any slot; whether it sits in *its* slot is the LOCK_MISMATCH check.
## [br]- F2 "allowed" excludes guests (owned only); locked guests come from step 1.
class_name TeamRules
extends RefCounted

## F1 failure reasons, in priority order (OK = valid).
enum Reason { OK, INCOMPLETE, DUPLICATE, UNKNOWN_CREW, NOT_OWNED, BANNED, LOCK_MISMATCH, COLOUR_CLASH }

## Empty slot marker in a draft / resolved team.
const EMPTY_SLOT := &""
## Allowed team sizes (rule 1).
const MIN_TEAM_SIZE := 1
const MAX_TEAM_SIZE := 3


## Starter crews in registry order (rule 9).
static func starters_in_registry_order(registry: CrewRegistry) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CrewDef in registry.crews:
		if c != null and c.starter:
			out.append(c.id)
	return out


## F1: first failing condition (priority INCOMPLETE > DUPLICATE > UNKNOWN_CREW >
## NOT_OWNED > BANNED > LOCK_MISMATCH > COLOUR_CLASH) or OK.
static func check_team(team: Array[StringName], rule: TeamRule, registry: CrewRegistry, owned: OwnedCrews) -> Reason:
	var r := rule if rule != null else TeamRule.make()
	if team.size() != r.team_size or team.has(EMPTY_SLOT):
		return Reason.INCOMPLETE
	var seen := {}
	for c: StringName in team:
		if seen.has(c):
			return Reason.DUPLICATE
		seen[c] = true
	for c: StringName in team:
		if registry.get_crew(c) == null:
			return Reason.UNKNOWN_CREW
	for c: StringName in team:
		if not owned.is_owned(c) and not r.is_locked_crew(c):
			return Reason.NOT_OWNED
	for c: StringName in team:
		if r.banned.has(c):
			return Reason.BANNED
	for l: TeamLock in r.locked:
		if l.slot < 0 or l.slot >= team.size() or team[l.slot] != l.crew_id:
			return Reason.LOCK_MISMATCH
	if colour_clash(team, registry):
		return Reason.COLOUR_CLASH
	return Reason.OK


## F1 as a bool.
static func is_valid_team(team: Array[StringName], rule: TeamRule, registry: CrewRegistry, owned: OwnedCrews) -> bool:
	return check_team(team, rule, registry, owned) == Reason.OK


## F3: two crews of the team share a colour slot.
static func colour_clash(team: Array[StringName], registry: CrewRegistry) -> bool:
	var slots := {}
	for c: StringName in team:
		var def := registry.get_crew(c)
		if def == null:
			continue
		if slots.has(def.colour_slot):
			return true
		slots[def.colour_slot] = true
	return false


## Rule 7: locked crews of [param team] the player does not own (guests), slot order.
static func guests(team: Array[StringName], rule: TeamRule, owned: OwnedCrews) -> Array[StringName]:
	var out: Array[StringName] = []
	var r := rule if rule != null else TeamRule.make()
	for c: StringName in team:
		if c != EMPTY_SLOT and not owned.is_owned(c) and r.is_locked_crew(c):
			out.append(c)
	return out


## Rule 6 stage-data validation (empty = valid; messages name the field).
## [param require_full_lock_below] — stage-goals rule 2: team_size < 3 must lock every slot.
static func validate_rule(rule: TeamRule, registry: CrewRegistry, require_full_lock_below: int = MAX_TEAM_SIZE) -> PackedStringArray:
	var errors := PackedStringArray()
	if rule == null:
		return errors
	if rule.team_size < MIN_TEAM_SIZE or rule.team_size > MAX_TEAM_SIZE:
		errors.append("team_rule.team_size %d out of %d..%d" % [rule.team_size, MIN_TEAM_SIZE, MAX_TEAM_SIZE])
		return errors
	var slots := {}
	var crews := {}
	var colours := {}
	for l: TeamLock in rule.locked:
		if l == null:
			errors.append("team_rule.locked: null entry")
			continue
		if l.slot < 0 or l.slot >= rule.team_size:
			errors.append("team_rule.locked: slot %d not < team_size %d" % [l.slot, rule.team_size])
		if slots.has(l.slot):
			errors.append("team_rule.locked: slot %d locked twice" % l.slot)
		slots[l.slot] = true
		if crews.has(l.crew_id):
			errors.append("team_rule.locked: crew %s locked twice" % l.crew_id)
		crews[l.crew_id] = true
		var def := registry.get_crew(l.crew_id)
		if def == null:
			errors.append("team_rule.locked: unknown crew %s" % l.crew_id)
			continue
		if rule.banned.has(l.crew_id):
			errors.append("team_rule.locked: crew %s is also banned" % l.crew_id)
		if colours.has(def.colour_slot):
			errors.append("team_rule.locked: colour_slot %d used twice" % def.colour_slot)
		colours[def.colour_slot] = true
	for b: StringName in rule.banned:
		if registry.get_crew(b) == null:
			errors.append("team_rule.banned: unknown crew %s" % b)
	if rule.team_size < require_full_lock_below and not rule.is_fixed():
		errors.append("team_rule.locked: team_size %d < %d must lock every slot" % [rule.team_size, require_full_lock_below])
	return errors


## Rule 6 lint: can the starter crews plus the stage's guests form a valid team?
static func starter_can_play(rule: TeamRule, registry: CrewRegistry) -> bool:
	var owned := OwnedCrews.starter(registry)
	var team := resolve_default_team(rule, registry, owned, TeamMemory.new(), &"")
	return is_valid_team(team, rule, registry, owned)


## F2 default team: locks, then the stage memory (else the global memory) keeps
## its slots, then empty slots fill from (stage memory ⧺ global ⧺ starters ⧺
## owned) in order. Returns N slots; unfilled ones are [constant EMPTY_SLOT].
static func resolve_default_team(rule: TeamRule, registry: CrewRegistry, owned: OwnedCrews, memory: TeamMemory, stage_id: StringName) -> Array[StringName]:
	var r := rule if rule != null else TeamRule.make()
	var team: Array[StringName] = []
	for s: int in r.team_size:
		team.append(r.locked_at(s))
	var m_stage: Array[StringName] = memory.stage_team(stage_id) if memory != null else []
	var m_global: Array[StringName] = memory.last_global.duplicate() if memory != null else []
	var candidates: Array[StringName] = []
	for list: Array[StringName] in [m_stage, m_global, starters_in_registry_order(registry), owned.owned_crew_ids()]:
		for c: StringName in list:
			if c != EMPTY_SLOT and not candidates.has(c):
				candidates.append(c)
	# Step 3: keep the remembered slots.
	var keep := m_stage if not m_stage.is_empty() else m_global
	for i: int in mini(keep.size(), team.size()):
		if team[i] == EMPTY_SLOT and _allowed(keep[i], team, r, registry, owned):
			team[i] = keep[i]
	# Step 4: fill empty slots in order from the candidates.
	for i: int in team.size():
		if team[i] != EMPTY_SLOT:
			continue
		for c: StringName in candidates:
			if _allowed(c, team, r, registry, owned):
				team[i] = c
				break
	return team


## Rule 13: the retry team is the last round's team, slot order kept (no F2).
static func team_for_retry(last_team: Array[StringName]) -> Array[StringName]:
	return last_team.duplicate()


## Rules 10–11: memory after confirming [param team] on [param stage_id]. The
## stage memory always records it; the global memory only a 3-crew guest-free team.
static func remember(memory: TeamMemory, stage_id: StringName, team: Array[StringName], rule: TeamRule, owned: OwnedCrews) -> TeamMemory:
	var out := memory.copy() if memory != null else TeamMemory.new()
	out.by_stage[stage_id] = team.duplicate()
	if team.size() == MAX_TEAM_SIZE and guests(team, rule, owned).is_empty():
		out.last_global = team.duplicate()
	return out


static func _allowed(c: StringName, team: Array[StringName], rule: TeamRule, registry: CrewRegistry, owned: OwnedCrews) -> bool:
	var def := registry.get_crew(c)
	if def == null or not owned.is_owned(c) or rule.banned.has(c) or team.has(c):
		return false
	for x: StringName in team:
		if x == EMPTY_SLOT:
			continue
		var other := registry.get_crew(x)
		if other != null and other.colour_slot == def.colour_slot:
			return false
	return true
