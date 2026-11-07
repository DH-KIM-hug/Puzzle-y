# ADR-0001: 순수·결정적 규칙 코어 — 미리보기와 실제 배치가 공유하는 연쇄 해석기, 시드 RNG

## Status
Proposed

## Date
2026-11-07

## Last Verified
2026-11-07 — Godot 4.7.2 headless(`/usr/local/bin/godot`)에서 아래 Engine Compatibility의 API를 probe 스크립트로 확인.

## Decision Makers
사용자(전권 위임 "알아서 진행" — 질문 없이 권장안 채택), `/architecture-decision` 작성 세션.
`godot-specialist` 검증·`technical-director` TD-ADR 검토는 받지 않음 (아래 Validation Criteria의 "건너뛴 게이트").

## Summary
말랑 크루의 보드 규칙·연쇄 해석·점수·트레이 생성을 미리보기와 실제 배치가 **한 벌의 구현**으로 공유해야 하고(기둥 3 "미리보기 ≠ 결과면 버그"),
랜덤이 미리보기·재도전·테스트의 결정성을 깨서는 안 된다. 이를 위해 이 규칙들을 Node·씬에 의존하지 않는 순수 GDScript(`RefCounted` 값 객체 +
`static func`)로 `src/core/rules/`에 두고, 해석기는 이벤트 목록을 내며 연출은 그것을 재생만 하고, 모든 랜덤은 `(stage_seed, 스트림 태그, 인덱스)`의
자체 32비트 해시로 뽑기마다 파생한 시드만 쓰며, 크루는 능력 프리미티브를 데이터로 조합한 Custom Resource(`.tres`)로 정의한다.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (설치 4.7.2.stable.official.ed1daf0bf) |
| **Domain** | Core (Scripting) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (4.5–4.7 모두 LLM 컷오프 이후) — 단, 이 결정이 쓰는 API는 4.0–4.4 기능이라 실질 위험은 LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md` (GDScript 4.5+/4.7, Resources 4.5+, Command Line). `modules/`에 scripting/core 문서는 없음 (NOT SOURCEABLE) |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()` (4.5) — 테스트에서 데이터 불변성 검증용으로만. 4.7 typed-return override 규칙은 영향을 받는 코드 형태(가상 메서드 오버라이드)를 이 설계가 쓰지 않음으로써 회피 |
| **Verification Required** | (1) `SeedHash`/`DetRng` 골든 값이 Android(arm64) 실기기와 데스크톱에서 같음; (2) `ChainResolver.resolve` 최악 근사 입력 ≤ 1 ms(데스크톱 headless), 저가 Android에서 미리보기 몫 ≤ 4 ms (chain-preview F3); (3) `.tres`의 `@export var params: Dictionary` 값이 에디터 저장·로드 왕복 후 int 타입을 유지 (float로 바뀌지 않음) |

**4.7.2 headless probe로 확인한 것 (2026-11-07)**: `RefCounted` 내부 클래스의 `static func`, `Callable(Class, &"static_fn")` 호출,
타입 딕셔너리 `Dictionary[StringName, Array]`, `Dictionary.make_read_only()` / `Array.make_read_only()`, `Vector2i` 딕셔너리 키,
`PackedInt32Array.duplicate()`의 값 복사, `String.to_utf8_buffer()`, 커스텀 `Resource`의 `@export var steps: Array[Sub]`와 `duplicate_deep()`,
int 64비트 덧셈 랩어라운드, 음수 int의 `>>`는 산술 시프트(−1 >> 1 = −1), 음수 **리터럴**의 시프트는 파스 오류. `RandomNumberGenerator`는 존재하나 채택하지 않음.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — 첫 ADR. `docs/registry/architecture.yaml`의 모든 섹션이 비어 있고 `docs/architecture/`에 다른 ADR이 없음을 확인 |
| **Enables** | 판 진행 흐름 상태 머신 ADR(커밋·연출 대기·`ResolveContext` 공급), 로컬 세이브 스키마 ADR(`crew_id`·시드 저장), 연쇄 미리보기 렌더링 ADR(오버레이 그리기 방식·캐시 — chain-preview가 ADR 대상으로 남긴 부분), 가챠 RNG(이 ADR의 스트림 규칙 재사용) |
| **Blocks** | 보드 & 조각 규칙 · 연쇄 해석기 · 점수 · 트레이 공급 · 크루 정의 · 연쇄 미리보기 epic의 구현 스토리 (아직 스토리 없음) |
| **Ordering Note** | 칸 종류 & 방해물 GDD(미작성)는 이 ADR의 `ChainHooks` 계약을 따라야 한다. 스테이지 & 목표 GDD는 `stage_seed` 범위(0–2³¹−1)와 `tray_seed_mode`를 이 ADR의 `SeedHash`로 해석한다 |

## Context

### Problem Statement
이 게임의 핵심 약속은 "드래그 중 본 연쇄가 놓으면 그대로 터진다"이다. 미리보기, 실제 배치, 자동 플레이 테스트, (장래의) 리플레이가 모두
같은 결과를 내려면 규칙 계산이 한 곳에만 있어야 하고 그 계산이 결정적이어야 한다. GDD 6건(board-rules, chain-resolver, scoring, tray-supply,
crew-definition, chain-preview)이 규칙의 의미를 정했지만 모두 구현 형태 — 모듈 형태, 보드 복제 방식, 프리미티브 표현, 해시·PRNG 선택,
`RandomNumberGenerator` 수명, 크루 리소스 분할 — 를 이 ADR로 미뤘다 (chain-resolver Q7, tray-supply Q6, crew-definition 규칙 1·3, scoring Overview).
첫 구현 스토리 전에 정해야 한다.

### Constraints
- **TD-PHASE-GATE 조건** (gate-check 2026-11-07): 해석기는 순수 함수(보드 + 배치 → 이벤트 목록), 연출은 이벤트 재생만; 능력 랜덤은 주입된 시드 RNG만;
  깊이 상한 6은 데이터이며 상한 도달 동작이 정의됨; 미리보기는 앵커 칸이 바뀔 때만 재계산(< 1 ms 추정, 실기기 미측정); 크루는 능력 프리미티브를 조합한 Custom Resource.
- Godot 4.7 / GDScript, 모바일(Android) 대상, Compatibility 렌더러, 60 fps (16.67 ms) 프레임 예산.
- 정수 연산만 (chain-resolver 규칙 2, scoring 규칙 2) — 플랫폼 간 결정성.
- GDScript `int`는 부호 있는 64비트: 32비트 부호 없는 곱셈을 그대로 쓰면 2⁶³을 넘을 수 있다. 음수 시프트는 산술 시프트다.
- 개인 개발(`team.size: individual`), standard rigor — 과설계 금지.

### Requirements
- 같은 입력 → 같은 `events`(순서 포함)·`final_board`·점수·트레이 순서, 플랫폼·실행 횟수와 무관.
- 미리보기와 커밋이 **같은 함수, 같은 `ctx`**를 호출한다는 것이 코드 구조로 보장될 것.
- 규칙 코드가 씬 트리 없이 gdUnit4 단위 테스트에서 돌 것 (DI, 싱글턴 없음).
- 새 크루는 코드 없이 `.tres` 한 장으로 추가 (기둥 2), 새 방해물은 해석기 수정 없이 훅으로 (chain-resolver 규칙 21).
- `resolve` 최악 ≤ 1 ms 데스크톱 headless (chain-resolver F8, AC-17), 미리보기 몫 ≤ 4 ms 저가 Android (chain-preview F3).

## Decision

규칙 계산 전체를 **Rules Core** — `src/core/rules/` 아래의 Node 없는 순수 GDScript — 로 둔다. Rules Core는 값을 받아 새 값을 돌려주는
`static func`과, 그 값을 담는 `RefCounted` 값 객체로만 이루어진다. 데이터(크루·규칙 수치)는 `Resource`로 로드하되 Rules Core는 그것을 읽기만 한다.
Node 세계(판 진행 흐름, 미리보기 표시, 연출 재생기)는 Rules Core를 **호출만** 하고, Rules Core는 Node 세계를 모른다.

1. **모듈 형태 — 상태 없는 정적 함수 + 불변 값 객체.** `BoardRules`, `ChainResolver`, `ScoreCalculator`, `TraySupplyRules`, `SeedHash`는
   인스턴스를 만들지 않는 `static func` 모음(`class_name X extends RefCounted`, 인스턴스 필드 없음)이다. 상태는 인자로 들어오고 반환값으로 나간다.
2. **보드 = 구조-of-배열 값 객체, 복사 후 쓰기.** `BoardState`는 `width`, `height`와 칸별 `PackedByteArray kind`, `PackedByteArray flags`
   (`is_face`, `origin`), `Array[StringName] crew`(빈 `&""` = null), `PackedInt32Array placement_id`, `Dictionary modifiers`(희소: 칸 인덱스 →
   `PackedInt32Array`)를 갖는다. 변경 연산은 `BoardState.copy()`(packed 배열 `duplicate()` = 64칸 memcpy)로 사본을 만들고 사본에만 쓴다.
   해석기는 `resolve` 시작 시 한 번 복사한 작업 보드를 웨이브 내내 제자리 수정하고(**내부 최적화, 외부 관찰 불가**), CLEAR 스냅샷(규칙 15)이
   필요한 곳에서만 추가 복사한다. 입력 보드는 절대 바뀌지 않는다.
3. **해석기 = 이벤트 목록을 내는 동기 함수.** `ChainResolver.resolve(board, piece, anchor, ctx) -> ChainResult`는 chain-resolver 규칙 6의 루프를
   그대로 구현하고 `ChainResult{events, final_board, summary}`를 돌려준다. 연출·HUD·오디오·스테이지 목표·점수는 `events`만 읽는다.
4. **이벤트 = 공통 필드가 타입 지정된 `ChainEvent` + 스키마 키 상수가 있는 payload.** 이벤트 9종(GDD 규칙 19)마다 클래스를 만들지 않고,
   `ChainEvent`(`seq: int`, `type: ChainEvent.Type`, `wave: int`(−1 = null), `data: Dictionary`)와 `ChainEvent.K_*` 키 상수로 표현한다.
   `ChainResult` 반환 전에 이벤트 `data`와 목록 전체를 `make_read_only()` 한다 — 소비자가 결과를 바꿔 미리보기·커밋이 어긋나는 것을 막는다.
5. **점수 = 이벤트를 읽는 별도 순수 함수.** `ScoreCalculator.score_placement(events, rules: ScoringRules) -> ScoreBreakdown`. 해석기는 점수를 모른다(규칙 20).
6. **트레이 = 상태 객체 + 순수 전이 함수.** 트레이는 가방 상태가 필요하므로 상태를 `TrayState`(가방 내용·인덱스·슬롯) 값 객체로 두고
   `TraySupplyRules.init_state(team, cfg, stage_seed) -> TrayState`, `refill(state, board, budget) -> TrayRefill{state, pieces, rescued}`,
   `consume(state, slot) -> TrayState`가 새 상태를 돌려준다. 판 진행 흐름이 현재 `TrayState`를 보관한다.
7. **시드 RNG = 자체 32비트 해시 + 카운터 기반 PRNG, 뽑기마다 시드 파생.** `RandomNumberGenerator`와 전역 `randi()`/`randf()`/`randomize()`를
   Rules Core에서 쓰지 않는다. `SeedHash.hash32(parts: Array[int]) -> int`(murmur3 방식 혼합 + `fmix32` 마무리, 모든 곱셈은 16비트 분할
   `mul32`로 2⁴⁸ 미만 유지, 결과 `& 0xFFFFFFFF`)가 GDD의 `hash32(stage_seed, STREAM_*, index…)`이다. 뽑기 한 번 = `DetRng.new(hash32([...]))`;
   `DetRng.next_u32()` = `hash32([seed, counter])`, `DetRng.below(n)` = `(next_u32() * n) >> 32` (n < 2³¹이면 곱이 2⁶³ 미만 — probe 확인).
   `crew_key(id)` = `SeedHash.str32(String(id))` (UTF-8 바이트 FNV-1a 32). Godot `String.hash()`는 버전 간 고정 보장이 없어 쓰지 않는다.
   스트림 태그는 `SeedStreams` 상수(아래)로 고정하며, 값을 바꾸면 모든 FIXED 스테이지 재검증이 필요하다(tray-supply Edge Cases).
8. **크루 = 데이터 전용 Custom Resource, 능력 단계 = `StringName` + `Dictionary`.** `CrewDef`/`CrewShapeEntry`/`CrewAbility`/`AbilityStep`/`PieceShape`는
   스크립트 로직 없는 `Resource`다. `AbilityStep{primitive: StringName, params: Dictionary}`이며, 프리미티브의 의미는 코드 쪽 `PrimitiveLibrary`
   (id → 정적 실행 함수 + 파라미터 검증기)가 소유한다. `CrewRegistry.load_and_validate()`가 시작 시 1회 검증(crew-definition 규칙 12, chain-resolver 규칙 18)
   후 해석기용 `AbilityTable`(crew_id → 읽기 전용 단계 배열, **레지스트리 전체**)을 만든다. 해석기는 `Resource`를 직접 만지지 않고 이 표만 읽는다.
9. **미리보기 재사용 = 같은 컨텍스트 팩토리 + 같은 함수.** 판 진행 흐름(`RoundFlow`, Node)만 `ResolveContext`를 만든다:
   `RoundFlow.context_for_next_placement() -> ResolveContext`(`abilities`, `rules`, `rng_seed = hash32([stage_seed, STREAM_RESOLVER, placement_index])`, `hooks`).
   미리보기(`ChainPreview`)는 이 메서드로 받은 `ctx`와 현재 안정 보드로 `ChainResolver.resolve`를 부르고, 커밋 시 `RoundFlow`는 **같은 메서드로 받은 `ctx`**로
   독립적으로 다시 부른다(chain-preview 규칙 9 권위 경로). 디버그 빌드는 마지막 미리보기 `summary.board_hash`와 커밋 결과를 비교해 `PREVIEW_MISMATCH` assert.
   미리보기 LRU 캐시 키 = (`board_version`, `piece.instance_id`, `anchor`, `ctx.rng_seed`); 꺼도 결과 동일.

### Architecture Diagram

```
 data (.tres, read-only)               Rules Core (src/core/rules — no Node, no globals)
 ─────────────────────────            ───────────────────────────────────────────────────
 assets/data/crew/*.tres ──load──▶ CrewRegistry ──build──▶ AbilityTable (read-only)
 assets/data/rules/*.tres ─load──▶ BoardConfig · ChainRules · ScoringRules · TrayRules
                                          │
 Node world (src/gameplay, src/presentation)            ▼
 ┌──────────────┐  context_for_next_placement()  ┌──────────────────┐
 │  RoundFlow   │───────────── ctx ─────────────▶│ ChainResolver    │──uses──▶ BoardRules
 │ (Node, owns  │── resolve(board,piece,a,ctx) ─▶│  .resolve()      │──uses──▶ PrimitiveLibrary
 │  BoardState, │◀──────── ChainResult ──────────│ (static, pure)   │──uses──▶ ChainHooks (pure)
 │  TrayState)  │                                └──────────────────┘          SeedHash/DetRng
 └──┬───┬───┬───┘                                         ▲
    │   │   └─ events ─▶ ScoreCalculator.score_placement (pure) ─▶ ScoreBreakdown
    │   │                                                  │ same function, same ctx
    │   └── events ─▶ ChainPlayer (presentation: replay only, never judges)
    │                                                      │
    └── ctx + board ─▶ ChainPreview (Node) ── resolve() ───┘  (LRU cache, anchor-change only)
    TraySupplyRules.init_state / refill / consume (pure) ◀─▶ TrayState held by RoundFlow
```

### Key Interfaces

파일 배치 (Godot 코드 루트 `src/`, 테스트 `tests/unit/`):

```
src/core/rules/board/      board_state.gd (BoardState) · board_rules.gd (BoardRules) · cell_kind.gd (CellKind: 플래그 3종 표)
                           piece_shape.gd (PieceShape, Resource) · piece_instance.gd (PieceInstance) · board_config.gd (BoardConfig, Resource)
src/core/rules/chain/      chain_resolver.gd (ChainResolver) · resolve_context.gd (ResolveContext) · chain_result.gd (ChainResult)
                           chain_event.gd (ChainEvent) · chain_rules.gd (ChainRules, Resource) · chain_hooks.gd (ChainHooks)
                           primitive_library.gd (PrimitiveLibrary)
src/core/rules/scoring/    score_calculator.gd (ScoreCalculator) · scoring_rules.gd (ScoringRules, Resource) · score_breakdown.gd
src/core/rules/tray/       tray_supply_rules.gd (TraySupplyRules) · tray_state.gd (TrayState) · tray_rules.gd (TrayRules, Resource)
src/core/rules/rng/        seed_hash.gd (SeedHash) · det_rng.gd (DetRng) · seed_streams.gd (SeedStreams)
src/core/data/crew/        crew_def.gd · crew_shape_entry.gd · crew_ability.gd · ability_step.gd · crew_registry.gd · ability_table.gd
assets/data/crew/<id>.tres · assets/data/crew/crew_registry.tres · assets/data/shapes/<shape_id>.tres · assets/data/rules/{board,chain,scoring,tray}_rules.tres
tests/unit/rules/          board/ · chain/ · scoring/ · tray/ · rng/ · purity/   (gdUnit4)
```

```gdscript
# 좌표: Vector2i(row, col) — x = row, y = col. 화면 좌표로 쓰지 않는다. 칸 인덱스 = row * width + col.
class_name BoardRules extends RefCounted
static func can_place(board: BoardState, piece: PieceInstance, anchor: Vector2i) -> bool
static func place(board: BoardState, piece: PieceInstance, anchor: Vector2i, placement_id: int) -> BoardState
static func full_lines(board: BoardState) -> LineSet                 # rows 오름차순, cols 오름차순 (행 먼저)
static func line_cells(board: BoardState, lines: LineSet) -> PackedInt32Array   # row-major 칸 인덱스
static func clear_cells(board: BoardState, cells: PackedInt32Array) -> ClearResult  # {board, cleared: Array[ClearedCell]} row-major
static func fill_cells(board: BoardState, cells: PackedInt32Array, origin: int, crew_id: StringName) -> BoardState
static func line_fill_count(board: BoardState, axis: int, index: int) -> int
static func empty_cells_in_line(board: BoardState, axis: int, index: int) -> PackedInt32Array
static func any_fit(board: BoardState, piece: PieceInstance) -> bool
static func no_moves(board: BoardState, pieces: Array[PieceInstance]) -> bool
static func validate_board(board: BoardState, config: BoardConfig) -> PackedStringArray   # 빈 배열 = 유효

class_name ChainResolver extends RefCounted
## Pure. Same (board, piece, anchor, ctx) → identical ChainResult. Never mutates inputs.
static func resolve(board: BoardState, piece: PieceInstance, anchor: Vector2i, ctx: ResolveContext) -> ChainResult

class_name ResolveContext extends RefCounted    # 생성 후 읽기 전용으로 취급
var abilities: AbilityTable      # crew_id → Array[{primitive, params}] (registry 전체, read-only)
var rules: ChainRules            # depth_cap (6), face_order, max_waves_guard = depth_cap + 1
var rng_seed: int                # SeedHash.hash32([stage_seed, SeedStreams.RESOLVER, placement_index])
var hooks: ChainHooks            # 기본값 = pre_clear→CLEAR, can_activate→true, target_filter→true

class_name ChainHooks extends RefCounted
var pre_clear: Callable      # (board: BoardState, cell: int) -> Dictionary {keep: bool, modifiers: PackedInt32Array}
var can_activate: Callable   # (board: BoardState, cell: int) -> bool
var target_filter: Callable  # (board: BoardState, cell: int, primitive: StringName) -> bool

class_name ChainResult extends RefCounted
var events: Array[ChainEvent]    # read-only, seq 0..n-1
var final_board: BoardState
var summary: Dictionary          # CHAIN_END payload: chain_depth, waves, ..., board_hash (read-only)

class_name ChainEvent extends RefCounted
enum Type { PLACED, WAVE_BEGIN, CELL_MODIFIED, CELLS_CLEARED, FACE_ACTIVATED, ABILITY_EFFECT, FACE_FIZZLED, DEPTH_CAP_REACHED, CHAIN_END }
var seq: int
var type: Type
var wave: int = -1               # -1 = null (PLACED, CHAIN_END)
var data: Dictionary             # keys = ChainEvent.K_* constants, per chain-resolver rule 19 schema

class_name PrimitiveLibrary extends RefCounted
## id → static executor. CLEAR executors return target cells on the snapshot; FILL executors return egg cells in lay order.
static func execute(primitive: StringName, params: Dictionary, snapshot: BoardState, face_cell: int, ctx: ResolveContext) -> PackedInt32Array
static func kind_of(primitive: StringName) -> int          # KIND_CLEAR | KIND_FILL
static func validate(primitive: StringName, params: Dictionary) -> PackedStringArray

class_name ScoreCalculator extends RefCounted
static func score_placement(events: Array[ChainEvent], rules: ScoringRules) -> ScoreBreakdown

class_name TraySupplyRules extends RefCounted
static func init_state(team: Array[StringName], cfg: TrayRules, stage_seed: int, registry: CrewRegistry) -> TrayState
static func refill(state: TrayState, board: BoardState, budget: int) -> TrayRefill   # {state, pieces, rescued}
static func consume(state: TrayState, slot: int) -> TrayState

class_name SeedHash extends RefCounted
static func hash32(parts: Array[int]) -> int     # 0 .. 2^32-1; murmur3-style mix + fmix32, mul32 split multiply
static func str32(text: String) -> int           # FNV-1a 32 over to_utf8_buffer()  (= crew_key)
static func mul32(a: int, b: int) -> int         # (a * b) mod 2^32 without exceeding 2^48

class_name DetRng extends RefCounted
func _init(seed: int) -> void
func next_u32() -> int                            # hash32([seed, counter++])
func below(n: int) -> int                         # 0 .. n-1, (next_u32() * n) >> 32, requires 1 <= n < 2^31
static func shuffle(items: Array, seed: int) -> Array   # Fisher–Yates on a copy; input untouched

class_name SeedStreams extends RefCounted
const RESOLVER := 0x5245534F        # "RESO"
const TRAY_CREW := 0x54435257       # "TCRW"
const TRAY_SHAPE := 0x54534850      # "TSHP"
const TRAY_FACE := 0x54464143       # "TFAC"
const TRAY_RESCUE := 0x54525343     # "TRSC"
const TRAY_FACELESS := 0x54464C53   # "TFLS"
const ATTEMPT := 0x41545450         # "ATTP"
const GACHA := 0x47414348           # "GACH" (가챠 GDD가 하위 스트림을 정의)

# src/core/data/crew — data only, no logic beyond validation
class_name CrewDef extends Resource          # @export id: StringName, schema_version, name_key, colour_slot, rarity, shapes: Array[CrewShapeEntry], ability: CrewAbility, ...
class_name CrewShapeEntry extends Resource   # @export shape: PieceShape, weight: int = 1, face_cell: int = -1
class_name CrewAbility extends Resource      # @export ability_id: StringName, steps: Array[AbilityStep]
class_name AbilityStep extends Resource      # @export primitive: StringName, params: Dictionary
class_name CrewRegistry extends Resource     # @export crews: Array[CrewDef]; load_and_validate() -> PackedStringArray; abilities() -> AbilityTable
```

### Implementation Guidelines
- `src/core/` 아래 스크립트는 `RefCounted` 또는 `Resource`만 상속해야 하며 `Node`, `SceneTree`, `get_tree()`, 시그널 연결, autoload 이름을 참조해서는 안 된다.
- Rules Core는 `randi`, `randf`, `randomize`, `RandomNumberGenerator`, `Time`, `OS`, `Engine`(디버그 assert 외), `String.hash()`, `hash()`를 써서는 안 된다. 랜덤은 `DetRng`/`SeedHash`만.
- Rules Core는 `float`를 써서는 안 된다 — 배율은 백분율 정수, 나눗셈은 정수 나눗셈(scoring 규칙 2).
- 32비트 부호 없는 값끼리의 곱은 반드시 `SeedHash.mul32`로 해야 한다. 시프트 피연산자는 반드시 음이 아닌 값(마스킹 후)이어야 한다.
- 모든 공개 함수는 입력 인자(`BoardState`, `TrayState`, 배열, 딕셔너리, `Resource`)를 변경해서는 안 된다. 변경이 필요하면 `copy()` 사본에 쓴다.
- 미리보기와 커밋은 반드시 `RoundFlow.context_for_next_placement()`가 만든 `ResolveContext`로 `ChainResolver.resolve`를 불러야 한다. 미리보기 전용 근사 경로, 연출용 판정 코드는 금지.
- 연출 재생기·HUD·오디오는 `ChainResult.events`만 읽어야 하며 `BoardRules`를 호출해 상태를 다시 판정해서는 안 된다 (`final_board`를 표시용으로 읽는 것은 허용).
- 크루별 분기(`if crew_id == &"nyangi"`)를 코드에 두어서는 안 된다. 크루 동작은 `AbilityStep` 데이터 + `PrimitiveLibrary`로만.
- 새 프리미티브는 `PrimitiveLibrary`에 실행기 + 검증기 + chain-resolver GDD 규칙 14 표 갱신 + 골든 테스트를 함께 추가해야 한다. `uses_rng` 프리미티브는 chain-resolver Q4가 결정될 때까지 금지.
- 런타임에 `CrewDef`/규칙 `Resource`를 수정해서는 안 된다. 해석기는 `AbilityTable`만 읽는다.
- `Resource` 하위 클래스에서 가상 메서드를 오버라이드하지 않는다(4.7 typed-return 상속 규칙 회피). 부득이하면 모든 경로에 명시적 `return`.
- `CHAIN_END.board_hash` = `SeedHash.hash32`를 칸 배열 순서대로 접은 값 — 골든 테스트와 `PREVIEW_MISMATCH` 비교의 키.
- 각 공개 API에 `##` 문서 주석 (coding-standards).

## Alternatives Considered

### Alternative 1: Node 기반 규칙 서비스 (autoload `BoardService`/`ChainService`)
- **Description**: 보드 상태를 autoload Node가 들고, 해석·점수를 메서드와 시그널로 제공. 미리보기는 서비스의 "시뮬레이션 모드"를 호출.
- **Pros**: Godot 튜토리얼에 흔한 형태, 시그널로 연출 연결이 쉬움.
- **Cons**: 씬 트리 없이 테스트 불가(DI 위반), 미리보기가 상태를 건드리지 않도록 모드 플래그가 필요 — 미리보기 ≠ 결과 버그의 온상, 시그널 순서가 연출 타이밍에 묶임.
- **Rejection Reason**: TD 조건(순수 함수)과 coding-standards(싱글턴 대신 DI)를 직접 위반.

### Alternative 2: Godot `RandomNumberGenerator` 인스턴스 (스트림당 1개, 순차 소비)
- **Description**: 스트림마다 `RandomNumberGenerator`를 `seed`로 만들고 판 동안 순차로 뽑는다 (chain-resolver 규칙 22 원문의 제안).
- **Pros**: 엔진 내장(PCG32), 코드 적음, `randi_range` 등 편의 함수.
- **Cons**: 시드→수열과 `randi_range` 알고리즘이 Godot 버전 간 고정이라는 보장이 문서에 없음(tray-supply Q6) — 엔진 업그레이드가 FIXED 스테이지의 트레이 순서를 조용히 바꿀 수 있다. 순차 소비면 구제·스크립트 여부가 이후 순서를 흔든다(tray-supply D10이 기각).
- **Rejection Reason**: 버전 간 재현성과 "뽑기마다 독립 시드"(tray-supply D10)를 동시에 만족하지 못함. 자체 해시는 ~40줄이고 골든 값으로 잠글 수 있다.

### Alternative 3: 프리미티브마다 `Resource` 하위 클래스 + 가상 `execute()`
- **Description**: `ClearCrossStep extends AbilityStepBase`처럼 프리미티브별 타입 지정 `@export` 필드와 실행 메서드를 가진 리소스.
- **Pros**: 인스펙터에서 파라미터가 타입 지정되어 오타가 줄어듦, 디스패치 표 불필요.
- **Cons**: 데이터 파일이 코드(스크립트 경로)를 품어 "크루 = 코드 없는 데이터"(crew-definition 규칙 1)가 흐려짐, 4.7 typed-return 오버라이드 함정, 순수성 검사 대상이 리소스까지 퍼짐, GDD 스키마(`{primitive, params}`)와 어긋남.
- **Rejection Reason**: 검증은 로드 시 `PrimitiveLibrary.validate`로 충분히 얻고(chain-resolver 규칙 18), 데이터/로직 분리가 더 중요. T1 이후 인스펙터 불편이 크면 `@tool` 편집기 플러그인으로 보완.

### Alternative 4: 이벤트 9종을 각각 클래스로
- **Description**: `WaveBeginEvent`, `CellsClearedEvent` … 타입 지정 필드.
- **Pros**: 정적 타입 검사.
- **Cons**: 클래스 9+개와 보일러플레이트, 스키마 변경 때마다 소비자 전부 수정; 4.7 오버라이드 규칙 위험 증가.
- **Rejection Reason**: 공통 필드 타입 지정 + `K_*` 키 상수로 오타 위험을 대부분 막으면서 표면을 작게 유지. 소비자가 늘어 문제가 보이면 재검토.

### Alternative 5: 보드를 `Dictionary[Vector2i, Cell]` 또는 칸별 객체 배열로
- **Pros**: 읽기 쉬움, 희소 확장 용이.
- **Cons**: 복사 비용·할당이 칸 수에 비례(객체 64개), 해시·비교가 느림 — 미리보기 예산(≤ 4 ms 저가 Android)에 불리.
- **Rejection Reason**: packed 배열 SoA가 복사·해시·비교 모두 싸고 결정적이다.

## Consequences

### Positive
- 미리보기 = 결과가 "같은 함수 + 같은 `ctx` 팩토리"라는 구조로 보장되고, `board_hash` 비교로 디버그에서 즉시 검출된다.
- 규칙 전체를 씬 없이 gdUnit4로 테스트할 수 있다 — GDD의 Logic AC(골든 이벤트 목록, `rng_seed` 불변, F7 동일 값)를 그대로 단위 테스트로 옮길 수 있다.
- 시드가 엔진 버전과 독립이라 FIXED 스테이지·리플레이(chain-resolver Q5)·버그 재현이 (stage_seed, team, 배치 목록)만으로 가능하다.
- 새 크루는 `.tres` 한 장, 새 방해물은 `ChainHooks` 구현 — 해석기 수정 없음.

### Negative
- `Dictionary` payload와 `params`는 정적 타입 검사를 받지 못한다 — 키 상수, 로드 시 검증, 골든 테스트로 보완해야 한다.
- 자체 해시/PRNG는 우리가 유지·검증해야 하며 통계 품질이 엔진 PCG32보다 검증이 덜 되어 있다(셔플 ≤ 수십 항목 용도라 수용).
- 사본 기반 API라 할당이 생긴다(웨이브당 스냅샷 1회 등). 측정 전까지는 수용.
- 인스펙터에서 `params` 편집이 불편하다(Dictionary 수동 입력, 정수/실수 혼동 위험 — Verification Required 3).

## Risks
- **`.tres` Dictionary의 int가 float로 저장/로드됨** → 검증기가 int 타입을 강제하고(`typeof == TYPE_INT`) 실패를 로드 오류로. T0 첫 크루 `.tres` 작성 시 왕복 테스트.
- **해시 구현 실수로 플랫폼 간 값이 다름** → `tests/unit/rules/rng/`에 고정 입력→고정 출력 골든 값; Android 실기기에서 같은 테스트(자체 결과 화면 또는 로그) 1회 실행.
- **누군가 미리보기 전용 단축 경로를 추가** → Implementation Guidelines의 금지 + `tests/unit/rules/purity/`의 정적 검사(금지 토큰 grep 결과를 관찰로 보고) + `PREVIEW_MISMATCH` assert.
- **`resolve`가 저가 Android에서 예산 초과** → 캐시(chain-preview 규칙 8), 앵커 변경 시에만 호출; 그래도 초과하면 스냅샷 복사를 칸 목록 기반 차분으로 바꾸는 내부 최적화(인터페이스 불변). T0에서 실측.
- **Engine specialist 미검증(이번 실행)** → Accept 전에 `godot-specialist` 검증을 받을 것.
- **`Callable` 훅이 순수성을 깨는 구현을 받음** → 방해물 GDD/ADR이 훅 구현을 `src/core/rules/chain/hooks/`의 정적 함수로 제한, 같은 금지 토큰 검사 적용.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| chain-resolver.md | 규칙 1–3: `resolve(board, piece, anchor, ctx) → ChainResult`, 순수·정수 연산, 미리보기·판 흐름·자동 테스트가 같은 `resolve` | Decision 1·3·9, `ChainResolver.resolve` 시그니처, 금지 규칙 |
| chain-resolver.md | 규칙 19: 이벤트 9종 스키마와 순서 | `ChainEvent.Type` + `K_*` payload, `seq` 연속, read-only 목록 |
| chain-resolver.md | 규칙 13–18: 능력 = `{primitive, params}` 목록, 7종 어휘, 로드 시 검증 | `AbilityStep` + `PrimitiveLibrary.execute/validate`, `CrewRegistry.load_and_validate` |
| chain-resolver.md | 규칙 21: 훅 3종 + 기본값, 순수 | `ChainHooks` Callable 3개, 기본값, 정적 함수 제한(Risks) |
| chain-resolver.md | 규칙 22–24, F7: 지역 스트림, `rng_seed = hash32(stage_seed, STREAM_RESOLVER, placement_index)`, MVP 프리미티브 RNG 미사용 | `SeedHash.hash32`, `SeedStreams.RESOLVER`, `context_for_next_placement`, `uses_rng` 금지 |
| chain-resolver.md | F8 / AC-17: `resolve` ≤ 1 ms 데스크톱 | SoA 보드, 작업 보드 1회 복사, Verification Required 2 |
| board-rules.md | 규칙 17: 모든 함수 순수, 한 벌 구현; 구현 형태·보드 복제 방식 → ADR | `BoardRules` 정적 함수, `BoardState` SoA + `copy()` |
| board-rules.md | 규칙 2: 칸 종류 이름이 아니라 플래그 3종만 읽음 | `CellKind` 플래그 표, 방해물이 행 추가 |
| scoring.md | 규칙 1–2: 이벤트·rules만 읽는 정수 순수 함수, `ScoringRules` 리소스 → ADR | `ScoreCalculator.score_placement(events, ScoringRules)` |
| tray-supply.md | 규칙 16–17, F3, D10: 트레이 전용 스트림 5종, 뽑기마다 (stage_seed, 태그, 인덱스) 시드, 재현 | `SeedStreams.TRAY_*`, `DetRng`, `TraySupplyRules` 순수 전이 + `TrayState` |
| tray-supply.md | Q6: `hash32`·스트림 값·`crew_key`, RNG를 Godot RNG로 할지 자체 PRNG로 할지 | 자체 해시/PRNG 채택, `str32` = `crew_key`, 태그 상수 확정 |
| crew-definition.md | 규칙 1–3, 8, 11–13: 크루 = `CrewDef` `.tres` 1장, 능력 표 = 레지스트리 전체, 시작 시 1회 검증 후 불변 | 데이터 전용 Resource 5종, `CrewRegistry`, read-only `AbilityTable`, 경로 `assets/data/crew/<id>.tres` |
| chain-preview.md | 규칙 1, 8–9: 같은 함수·같은 `ctx`, LRU 캐시 키, 커밋은 독립 재계산·불일치 assert | Decision 9, `context_for_next_placement`, `board_hash` 비교 |
| chain-preview.md | F3: 미리보기 몫 ≤ 4 ms 저가 Android | 앵커 변경 시에만 호출 + 캐시, Verification Required 2 |

## Performance Implications
- **CPU**: `resolve` 최악 근사 ~1,764 칸 연산(chain-resolver F8) + 이벤트 생성; 데스크톱 headless ≪ 1 ms 예상(미측정). 드래그 중 앵커 변경 시에만 1회. 프레임당 상시 비용 없음.
- **Memory**: 보드 1장 ≈ 64 B × 3 packed + 64 StringName 참조 ≈ 1 KB 미만; 미리보기 캐시 16개 × (결과 + 이벤트) ≈ 수십 KB.
- **Load Time**: 크루 6 + 모양 카탈로그 + 규칙 4 `.tres` 로드·검증 1회, 무시 가능.
- **Network**: 없음 (로컬 전용).

## Migration Plan
기존 코드 없음(`src/`는 비어 있음). 프로토타입(HTML)은 참고만 하고 이식하지 않는다. 구현 순서: `rng/` → `board/` → `chain/` → `scoring/` → `data/crew` → `tray/`,
각 단계 골든 테스트 먼저. 이후 `RoundFlow`·`ChainPreview`·`ChainPlayer`(Node 세계)가 이 API를 호출한다.

## Validation Criteria
- 골든 테스트: GDD AC의 고정 보드·조각·앵커 → 이벤트 목록(seq·type·payload)과 `board_hash`가 기대값과 일치, 2회 호출 결과 동일, 입력 불변.
- `rng_seed`를 바꿔도 MVP 크루의 결과가 동일(chain-resolver 규칙 24 AC). `seed_for(1201, 2)`가 미리보기·커밋 쪽에서 같은 값(AC-22).
- `SeedHash` 골든 값이 데스크톱과 Android에서 동일.
- 같은 `stage_seed`·팀으로 `TraySupplyRules` 트레이 순서가 재시작마다 동일.
- `tests/unit/rules/purity/`가 `src/core/`에서 금지 토큰(`extends Node`, `randi`, `RandomNumberGenerator`, `Time.`, `float` 타입 표기 등)을 관찰 0건으로 보고.
- 성능: headless 1,000회 평균 `resolve` ≤ 1 ms; T0 저가 Android 실측 `t_preview` ≤ 4 ms.
- **건너뛴 게이트 (이번 실행)**: Engine specialist 검증(5.5) — 이 세션에 Agent 도구가 없어 `godot-specialist`를 spawn하지 못함 (NOT ASSESSED). TD-ADR(5.6) — review_mode `lean`이라 생략. Accept 전 최소 `godot-specialist` 검증 권장.

## Related
- 첫 ADR — supersede·contradict 없음.
- `design/gdd/chain-resolver.md` (규칙 1–26, F7·F8, Q5·Q7), `board-rules.md` (규칙 1–17), `scoring.md` (규칙 1–2), `tray-supply.md` (규칙 16–18, F3, Q6),
  `crew-definition.md` (규칙 1–3, 8, 11–13), `chain-preview.md` (규칙 1, 8–9, F3).
- `production/gate-checks/gate-check-systems-design-2026-11-07.md` § Director Panel — TD-PHASE-GATE 조건.
- GDD 동기화 필요: chain-resolver 규칙 22의 "(Godot에서는 `RandomNumberGenerator` 인스턴스에 seed 지정)" → "`DetRng`(ADR-0001)"; tray-supply 규칙 16·F3의 "지역 RNG"는 `DetRng`, Q6 해소 표시; F7·F3의 "provisional" 해제는 이 ADR Accept 후.
