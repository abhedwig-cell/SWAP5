# SWAP5 Status-A current status

Date: 2026-09-16

This page is the current documentation entry point for the SWAP5 Status-A baseline. It summarizes the admitted capability boundary and points readers to the underlying acceptance and preservation authorities. It does not replace capability-specific scientific contracts, qualification records, or historical migration evidence.

!!! info "Later canonical development"
    This page remains the authority for the **frozen Status-A review denominator**. Later canonically admitted development, including the concrete SWAP5-MODFLOW6 production application chain through F-GC49D, is recorded separately in [Post-Status-A current canonical state](POST_STATUS_A_CURRENT_STATE.md). Those later capabilities do not retroactively change the frozen Status-A claim.

## Pinned current authority

- canonical branch: `integration/f-ci-canonical`
- current Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- release-readiness acceptance record: [`STATUS_A_RELEASE_READINESS_BASELINE.md`](https://github.com/abhedwig-cell/SWAP5/blob/992a5c657bfe10a10100f92e0cb77c4825ae65b6/tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md)

The Status-A authority is later than the pinned scientific production baseline but does not introduce a scientific production postimage change. Current scope claims therefore follow the Status-A acceptance record, while scientific implementation remains anchored to the production baseline and its admitted capability records.

Later canonical acceptance gates supersede earlier intermediate migration/status statements for current-state claims. Earlier records remain valid evidence for the bounded decisions they actually made.

## What Status-A means here

Status-A is the admitted current-canonical SWAP5 baseline. It is a bounded scientific and architectural acceptance boundary, not a claim that all possible SWAP functionality or future architecture has been implemented.

Within the admitted scope, SWAP5 preserves the relevant scientific behaviour and reference expectations while changing how execution, state ownership, rollback, persistence, orchestration and coupling boundaries are made explicit. The current architecture is described in [Current Status-A architecture](CURRENT_ARCHITECTURE.md).

## CANONICALLY ADMITTED NOW

The current Status-A denominator includes the following capability families within their admitted contracts:

| Capability | Current Status-A meaning |
| --- | --- |
| Reference preservation | Legacy/reference behaviour remains the scientific comparison basis for the admitted preservation scope. |
| Richards / soil-water core | The admitted soil-water core is part of the qualified scientific production baseline. Status-A does not broaden its physics beyond the accepted scope. |
| Transactional execution | Trial execution is separated from acceptance. Candidate effects can be accepted or rejected without silently mutating the authoritative committed state. |
| Trial / accept / retry / rollback | Attempts have explicit outcome semantics. Retry is an execution decision; rollback restores the accepted authority rather than treating a failed candidate as committed. |
| State ownership | Persistent committed state, tentative candidate state and disposable scratch/workspace are distinct architectural roles. |
| Solver versus execution policy | Numerical solving and the policy that accepts, retries or selects an execution outcome are separate responsibilities. |
| Restart v1 | The admitted restart capability preserves/reconstructs the bounded committed-state contract required by Restart v1. |
| Serialized MultiSWAP v1 | The admitted MultiSWAP capability is serialized orchestration of the qualified real-physics path. It is not parallel/concurrent real-physics execution. |
| Drainage | The admitted drainage capability is part of the current qualified production baseline and preservation surface. |
| Surface evaporation | The admitted surface-evaporation capability is part of the current qualified production baseline and preservation surface. |
| WOFOST runtime | WOFOST is admitted only for its bounded qualified runtime scope. This is not a claim of a broad stable public API or unrestricted WOFOST execution surface. |
| Snow | Snow is admitted only for the restricted one-call-daily path that was qualified and canonically closed. |
| Groundwater Coupling v1 | The admitted groundwater chain includes the bounded internal coupling contract and the current external gateway boundary. Coupling publication follows the accepted-state contract. |
| External groundwater gateway | Gateway v1 is the admitted structural external-coupling seam. Its existence does not itself admit a broad concrete MODFLOW backend or arbitrary external-backend semantics. |
| F-PE11 performance closure | F-PE11 preserves the already admitted call-local surface-evaporation allocation/scaling semantics. Its current-head closure was a `NO_OP`: no production/reference mutation was required. It is not a blanket whole-model, MultiSWAP or portable speed guarantee. |
| Permanent testbank / qualification | The current Status-A release-readiness authority inherits same-tree permanent baseline, smoke, kernel, transactional, independent-oracle, mixed-smoke and numerical suites plus capability-specific moving-current evidence. Earlier [`F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md`](../testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md) remains an important permanent-testbank architecture/snapshot, but it is explicitly bound to older canonical `379afd11…` and is not itself the preservation authority for `992a5c657…`. |

## Current preservation authority

For the pinned scientific production tree, the release-readiness record inherits the same-tree F-GC29 replay. It reports PASS for reference O0/O2 equality and closure, scientific gates, Restart v1, serialized MultiSWAP v1, drainage, surface evaporation, restricted Snow, Groundwater Coupling v1 and these permanent suites:

- `tests/run-baseline.sh`
- `tests/run-smoke.sh`
- `tests/run-kernel.sh`
- `tests/run-transactional.sh`
- `tests/run-independent-oracle.sh`
- `tests/run-mixed-smoke.sh`
- `tests/run-numerical.sh`

Restricted Snow also has an exact-head preservation workflow on `50346642…`. F-PE11 uses dependency-aware current-head preservation: its close authority records no relevant production/reference dependency change and therefore no duplicate admission or benchmark rerun was required.

This distinction matters because a permanent-testbank document can be architecturally authoritative for its recorded snapshot while not automatically covering a later canonical head.

## Deliberate bounds on current claims

The following statements are part of the current documentation contract:

- restricted Snow admission does not imply subdaily, multi-day, arbitrary-duration or advanced Snow semantics;
- serialized MultiSWAP v1 does not imply parallel or concurrent real-physics admission;
- inside the frozen Status-A denominator, Groundwater Coupling v1 and the external gateway do not imply broad MODFLOW backend evolution; later post-Status-A canonical work has separately admitted a concrete MODFLOW6 application chain through F-GC49D, as recorded in [Post-Status-A current canonical state](POST_STATUS_A_CURRENT_STATE.md);
- F-PE11 does not establish a guaranteed whole-model speedup, a general MultiSWAP speedup, a portable speed guarantee, automatic rebatching, execution-class switching, GPU execution or a change in physics;
- bounded WOFOST runtime admission does not create a broad stable public API;
- capabilities outside the Status-A denominator are not automatically defects. They are blockers only when an applicable acceptance authority classifies them that way.

See [Deliberate future scope](FUTURE_SCOPE.md) for the explicit non-admitted boundary.

## SWAP 4.3.1 relationship

SWAP 4.3.1 remains an important reference source for scientific preservation and historical behaviour. SWAP5 Status-A is not documented as a wholesale scientific rewrite. The architectural difference is that the admitted SWAP5 runtime makes execution state and acceptance boundaries explicit: tentative work is separated from committed state, retries and rollback are first-class execution outcomes, and restart, MultiSWAP and coupling operate through bounded ownership contracts.

A separate SWAP 4.3.1 to SWAP5 equivalence campaign may add further validation evidence. That evidence can be linked from the traceability layer after acceptance without changing this Status-A capability denominator.

## How to find authority for a claim

Use [Theory, code and evidence traceability](TRACEABILITY.md). Do not infer current status from an old migration plan, target architecture page or intermediate qualification record alone.

For current claims, use this precedence:

1. current canonical Status-A/release-readiness acceptance authority;
2. later capability-specific canonical admission/closure authority;
3. qualification evidence that remains valid for the unchanged relevant dependency surface;
4. capability scientific contract and implementation record;
5. historical migration or target-design documentation.

This precedence preserves historical evidence without allowing an earlier snapshot to override later canonical acceptance.

## Later bounded lower-boundary admission: LOW05-A

PR#974 canonically admits the homogeneous typed Fortran ordinary Reference DATE5/HBOT5 prescribed lower-face pressure-head adapter at `e88af3da54b743958b887d9cc15647227388333a`. Existing typed physics, transaction/restart/mass ownership and default groundwater-owned mode5 semantics are unchanged. Original proposal endpoint is frozen through sibling/retry staging; ordinary ownership is explicit and excludes GWledger/datum. [Closeout and claim ceiling](../migration/F-MIG431-LOW05A_CLOSEOUT.md) bind source, qualification and admission. Qualification run36964835178 proves bounded progress, rollback, restart and existing2/4/6/7/defaultGW5 preservation at O0/O2. It does not assert global green CI, a generic parser, mixed ownership, broad transient accuracy or migration of1/3/8.

## Later bounded MC-NUT01 review, 19 October 2026

The [MC-NUT01 closure review](../science/MC_NUT01_FINAL_CLOSURE.md) reconciles later canonical nutrient admissions through PR1319 against canonical `e122ff8f`. Actual source124-day and three730-day Reference Richards/WOFOST81/Soil-N profiles, bounded source-full/retained/calendar/humus/material-label semantics and native restart have scoped admission. Full historical MC-NUT01 closure remains blocked by the source gross-atmosphere/net-carrier mismatch and the recorded remaining input/application envelope. All nine master rows remain ACTIVE_MIGRATION; old complete-absence claims are superseded by the bounded evidence. This later review does not alter the frozen Status-A denominator.

## Later MC-SOL01 bounded closure, 2026-10-19

The [MC-SOL01 final closure](https://github.com/abhedwig-cell/SWAP5/blob/integration/f-ci-canonical/MC_SOL01_FINAL_CLOSURE.md) reconciles Reference matrix transport, reactive storage/decay, gross-source pond chemistry and positive-pond/soil age against canonical `e122ff8f`. Existing PR #1304/#1309 and later #1315/#1317/#1321 admissions are retained. Current real GNU O0/O2 and source-bound evidence are recorded in the existing MC-NUT/SOL trajectory3 status. This supplements the frozen Status-A denominator. It does not claim full historical/default activation. The four full historical sorption/decay/pond/age envelopes are explicitly parked with bounded re-entry criteria; aquifer remains REJECTED and RossFast remains frozen optional.

The later MC-SOL01 closure CI follow-up repairs and locally qualifies eight original build/instrumentation routes, retaining all physical assertions and production/reference code. The final closure and existing AGE03-CI status bind raw evidence, failed environment attempts and strict source/negative controls. Thomas-Gladwell remains unadmitted; no historical envelope is promoted.

MC-SOL01 final preservation additionally qualifies original F-KT22 O0/O2 compilation and both complete paired-runtime modes with shared builds. PR1327 owns repaired terminal hosted admission. EB-I25 exposes a separate reproducible outflow-fixture contract mismatch and is not credited as PASS; frozen historical CI scope/pin failures and nonselected solver research remain explicit exceptions in the final closure.

The later [file-driven solute column](../science/MC_SOL01_COLUMN_INPUT_CONTRACT.md)
has local GNU13.3 O0/O2 qualification for a four-node serialized Reference
application with positive pond/runon/runoff/infiltration/evaporation, prescribed
roots/drain/bottom, exact separate-process restart and complete-generation
publication. PR1329 admits this bounded application at `21cc8098`; all15 final-head
workflows and all five actual postmerge workflows pass, including application
run39464479365 and coupled-restart F-GC39464478982. This is explicit namelist input;
general historical SWP activation, a live crop and dynamic thermal decay remain
outside its bounded claim. The existing trajectory3 column-input entry owns the
evidence and recovery state; no master row is promoted.

PR1332 admits the schema2 grid successor at `fc6f52e0` for explicit immutable geometry
with 2 through 256 cells, including nonuniform and 138-cm profiles. All five new
grid cases retain O0/O2 and separate-process endpoint identity, closed water and
solute budgets and the original schema1 endpoint. The existing trajectory3
column-input successor owns canonical admission and evidence. A dry deep
0.001-day-window Reference rejection is retained as a reproducible numerical
limit; smaller windows and the wetter deep case are qualified without tolerance
changes. This extends the application grid, not full historical/default scope.

## MC-NUT01 historical gross-positive admission,20 October2026

PR1330 at `d118bcf1cacf7462cf62c27141cf306d7a4a52fb` admits explicit nonnegative historical gross atmospheric N independently of accepted net Richards water, through existing mineral/reactive/crop/calendar owners. Original analytical/full chemistry O0/O2, four730-day physical profiles,48 transition process restarts, actual water/N rollback and retained/thermal/54TCS6 preservation pass; all10 old endpoints remain exact. [The source-bound contract and canonical receipt](../science/MC_NUT01_HISTORICAL_GROSS_TOP_CONTRACT_20261020.md) supersede the unresolved reference-choice statement above. Negative aggregate retains an executed original-source depletion mass counterexample and remains rejected; automatic original atmosphere/ponded binding and remaining historical input/output envelopes are not promoted. The frozen Status-A denominator is unchanged.

### MC-NUT01 accepted dry-atmosphere successor (20October2026)

The [accepted-atmosphere contract](../science/MC_NUT01_ACCEPTED_ATMOSPHERE_BINDING_20261020.md) records automatic original rain/irrigation/runon-minus-runoff N input from accepted Reference hydraulic substeps, with accurate root integration. Fresh O0/O2 physical,52 transition continuations, retained/thermal/54 TCS6 and exact old endpoints qualify the bounded successor. Concurrent MC-SOL01 PR1332 and all178 executed grid providers are preserved. Actual canonical admission is recorded in the existing MC-NUT01-HIST-COMPLETE status; full historical/master closure remains false, with negative aggregate, snow/interception/persistent ponding, native/output and complete original-model limits retained.
