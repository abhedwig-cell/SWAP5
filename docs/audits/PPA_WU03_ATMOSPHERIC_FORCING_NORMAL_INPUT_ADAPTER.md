# PPA-WU03 atmospheric forcing and normal-input adapter boundary

**State:** CANONICAL_ADMITTED_CLOSED  
**Canonical basis:** `integration/f-ci-canonical@12beef3e91f90f88b101c13af72cd216bccc63e3`  
**Workunit:** PPA-WU03  
**Production owner:** PPA-WU01 / `mod_fmr_production_application_bootstrap`

## Purpose

PPA-WU03 closes the smallest normal forcing/application gap above the already admitted PPA-WU01 owner. It does not add atmospheric, interception, irrigation, evaporation, crop, root-stress, solver or transaction physics.

The admitted target is a bounded common forcing slice:

`normal interval input -> outer stateless adapter -> admitted reference-ET demand -> typed SWINTER=0 dynamic-top request -> admitted dynamic-top evaluation -> flux-regime effective forcing -> PPA-WU01 owner`

The adapter is deliberately outside the kernel-facing contracts. It owns no file, parser, calendar, stream, cursor, committed state, retry state or transaction lifecycle.

## Authority binding

The workunit is bound to the following canonical authorities.

- PPA-WU01: `src/runtime/mod_fmr_production_application_bootstrap.f90`, canonical admission PR #306.
- M1 typed external boundary: canonical closeout PR #316 / #318.
- Generic-time reference ET: `mod_reference_et_demand_process` plus `mod_fmr_reference_et_demand_binding`.
- Dynamic top boundary: `mod_b110_dynamic_top_boundary_provider` and its admitted application bindings.
- SWINTER=0 identity route: F-APP06.
- Rutter SWINTER=3: F-APP05/F-APP08, reconciled but intentionally not owned by this first WU03 slice because its canopy reservoir is persistent transaction state.
- Irrigation: F-APP07 is authority for fixed/scheduled management semantics. WU03 accepts only an already-resolved nonnegative surface irrigation rate and does not parse or schedule irrigation events.
- Generic time and transaction/retry semantics remain owned by the existing canonical runtime.

## Exact admitted slice

The production adapter may accept only:

- real-valued interval coordinates `t0 < t1`;
- a forcing validity span covering that interval;
- nonnegative precipitation rate;
- nonnegative reference ET in mm/day;
- explicit canopy view needed by the admitted SWETR=1 reference-ET demand route;
- `SWINTER=0` only;
- either no irrigation or an already-resolved nonnegative surface irrigation rate;
- a caller-supplied typed dynamic-top base request carrying state/control fields that remain owned by the existing top-boundary/runtime layer.

The adapter overlays only precipitation, resolved surface irrigation and the already-admitted reference-ET soil/pond evaporation demands. It does not reinterpret any other dynamic-top field.

For PPA-WU01 execution, only a dynamic-top result in the already-admitted pure flux regime, with no ponding or runoff publication, may be converted to `fmr_b110_physical_forcing_t%top_flux`. Head/ponded/runoff regimes fail closed in this WU03 slice rather than being pre-resolved outside the transactional top-boundary owner.

## Explicit exclusions

PPA-WU03 does not admit:

- filenames, paths, file units, parser records, stream state, cursors, line numbers or legacy record ordering;
- a legacy weather-file grammar;
- calendar/date parsing inside physics/runtime contracts;
- SWETR=0 PMdirect normal-input derivation;
- SWINTER=1/2;
- SWINTER=3/Rutter state ownership;
- irrigation schedule/event selection;
- snow, runon or management parsing;
- any new ET/interception/evaporation equation;
- a second FMR owner, committed-state store, timestep controller, retry controller or transaction lifecycle;
- dynamic-top head/ponding/runoff pre-resolution into PPA-WU01 fixed-flux forcing.

## Required production seam

PPA-WU01 may gain one narrow owner-facing method that runs an interval with caller-supplied already-resolved typed forcing while preserving the same owned committed state. The existing `run_standalone` route must remain behaviorally identical and delegate to the same implementation using its stored base forcing.

This seam is required so a normal forcing adapter can supply a new interval without rebuilding or replacing the PPA-WU01 owner. The forcing argument is read-only for the complete transaction call; retries therefore reuse the same value and cannot advance an ingestion cursor.

## Preregistered qualification matrix

1. **Normal-input materialization.** Common precipitation/reference-ET/canopy input materializes the admitted typed reference-ET result and SWINTER=0 dynamic-top request.
2. **Boundary hygiene.** Production adapter and owner-facing seam contain no filename/path/file-unit/parser/cursor/line-number/legacy-record-order/calendar-loop semantics.
3. **Generic time.** Non-integer and subdaily intervals are accepted when covered by the explicit forcing span. No one-day equality is imposed.
4. **Typed-vs-adapter identity.** A direct typed construction and WU03 materialization produce the same reference-ET demand, dynamic-top forcing fields and pure-flux effective forcing.
5. **PPA-WU01 ownership.** Two consecutive intervals execute through one initialized PPA-WU01 object; committed revisions advance without reinitializing state.
6. **Retry/rollback input stability.** Materialization is stateless and deterministic. Repeated A-B-A materialization is bit-stable, and runtime retries receive the same read-only effective forcing without any adapter cursor or consumption state.
7. **Fail closed.** Unsupported ET/interception/irrigation selectors, invalid spans, negative normal rates, nonfinite values and non-flux dynamic-top results are rejected without a result.
8. **O0/O2 preservation.** Owner qualification passes at O0 and O2 with stable output identity.
9. **Regression.** Existing PPA-WU01 owner qualification and affected F-APP/M1 preservation gates remain green.
10. **Independent qualification.** A separate test harness re-derives the expected typed mapping over a forcing/canopy/subdaily matrix and verifies fail-closed behavior without using the owner test oracle.

## Canonical admission

PR #323 was merged into `integration/f-ci-canonical` at `97c4471155001e12133109be5eb6bd95f799eb00`.

The canonical capability is intentionally narrow. A normal/common interval input can supply precipitation, SWETR=1 reference ET, an explicit canopy view and an already-resolved surface-irrigation rate under SWINTER=0. The adapter remains stateless and parser/calendar free. PPA-WU01 remains the only FMR and committed-state owner.

This admission does not convert the full legacy meteorological preprocessing family into SWAP5 production functionality. File/calendar ingestion, PMdirect normal-input derivation, Rutter canopy-state ownership, SWINTER=1/2, irrigation scheduling, snow/runon ingestion and dynamic-top head/ponding/runoff pre-resolution remain outside this workunit.

## Qualification evidence

The preregistered matrix Q1-Q10 is green on PR #323 subject head `74b3bcbfffc6efe7125e39e1c6052dd130e2a42d`.

- Workflow run `35374130545`, owner job `105694706631`: O0 and O2 PASS with stable output identity; common input materialization, generic subdaily time, direct-typed physics identity, PPA-WU01 ownership, A-B-A stateless input replay, fail-closed cases and hard-mass gate all PASS.
- Workflow run `35374130545`, independent job `105694706401`: 54 independently rederived forcing/canopy/time cases PASS at O0/O2, including reference-ET equation oracle, transport identity and fail-closed cases.
- Workflow run `35374130545`, preservation job `105694706721`: protected F-APP/M1 production blobs unchanged; PPA-WU01, F-APP07 and current M1 semantic preservation PASS.

The qualified production delta is limited to the stateless outer adapter and the read-only `run_standalone_with_forcing` handoff on the existing PPA-WU01 owner. No new state owner or physics owner was introduced.

## Exit

PPA-WU03 closes only when this bounded common forcing slice is canonically admitted, owner and independent qualification pass, PPA-WU01 remains the sole runtime/state owner, and the machine-readable Production Physics & Application Envelope register records the exact restrictions.

A broader meteorological grammar, PMdirect ingestion, Rutter ownership and calendar/file adapters remain separate future slices and are not implied by WU03 closure.
