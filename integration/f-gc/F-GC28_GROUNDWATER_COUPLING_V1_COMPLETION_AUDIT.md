# F-GC28 Groundwater Coupling v1 Current-Canonical Completeness, Architecture Closure & Final Gap Audit

## Decision

`GROUNDWATER_COUPLING_V1_FINAL_CLOSURE_GAPS_IDENTIFIED`

Groundwater Coupling v1 is **not** qualified for 100% completion on the audited current canonical. The frozen denominator is unchanged. The current evidence supports one primary frozen-denominator blocker, `G05`, not a collection of newly invented denominator items.

- Primary frozen-denominator hard gaps: **1** (`G05_END_TO_END_DIRECT_GROUNDWATER_COMPOSITION`).
- Concrete closure obligations inside G05: **6**.
- Production physics changed by F-GC28: **NO**.
- Production source changed by F-GC28: **NO**.
- Frozen denominator changed: **NO**.

## Authority pinning

Program authority:

- `regie/f-rg03-post-ci59p-program-rebaseline@aac2644149dda47282a25a39892c6dc808323dd0`
- tree `922f6f6bd9acf700d9d39a2aa5007597f3891b03`
- fixed denominator authority `56b86e29e0960e396059caf47c193440d571b709`
- fixed denominator tree `088bfe72e42ecbad5de12a823af82743a1854c5c`

Audited current canonical:

- `integration/f-ci-canonical@379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`
- tree `556221f62b4fde616981499eba68ef5460f5d83c`

F-RG03 classifies the groundwater domain D13 at 82%. It records G01 through G04 as 100% independently qualified, canonically admitted and preserved, while G05 remains `CONTRACT_ONLY_NOT_IMPLEMENTED` with the hard blocker `full direct-groundwater/MODFLOW composition not end-to-end qualified`. This audit does not replace or alter that denominator.

## Numbering reconciliation

The live branch namespace has implemented owner work through F-GC22. F-GC16 is, however, a qualified authority that already reserves the semantic owner sequence F-GC23 through F-GC27 for response tangent, coupling restart, MultiSWAP coupling, external groundwater/MODFLOW adapter conformance and final end-to-end admission. F-CI56 also explicitly names F-GC23 response-tangent composition as not admitted, while F-RG03 recommends F-GC24 for the broader G05 direct-groundwater composition lane. Those numbers are therefore not treated as genuinely unallocated merely because a same-number branch does not yet exist. F-GC28 is the first non-conflicting number found by the live namespace and authority audit.

## Frozen-v1 scope reconstruction

### FROZEN_V1_REQUIRED

The qualified restricted profile is `RESTRICTED_DIRECT_GROUNDWATER_COUPLING_V1`. Its frozen requirements are:

1. prescribed lower-boundary head / mode-5 direct coupling with explicit datum, units and sign conventions;
2. generic finite coupling window `[t0,t1]`, without midnight or one-day semantics;
3. checkpoint both sides at `t0`, predictor plus one corrector from the same committed origin, then commit the accepted corrector exactly once or roll back;
4. `H_SWAP ≈ H_GW` under an explicit provenance-bound interface tolerance owned consistently with application/temporal accuracy policy;
5. exact action/reaction `q_SWAP = -q_GW`, with no interface mass tolerance;
6. normal coupling cost of approximately two full SWAP trajectories per coupling window, predictor plus one corrector;
7. fail closed and request a smaller new outer coupling window when the restricted iteration is not accepted;
8. accepted whole-window response sensitivity where qualified, with finite difference only as reference/fallback;
9. runtime-owned cell/tile mapping and area-fraction aggregation, without a one-column/one-cell assumption;
10. accepted coupling-window restart/replay semantics, without persistence of rejected scratch or trial state;
11. MultiSWAP-compatible direct-groundwater execution and isolation;
12. external groundwater/aquifer adapter conformance and end-to-end restricted production admission;
13. diagnostics sufficient to audit window, lineage, accepted head/flux/transfer, head residual, mass residual and route.

### QUALIFIED_OPTIONAL

Numerical warm-start reuse is allowed but cannot change the committed physical origin. Alternative soil-water solvers may fail closed when an interface sensitivity is unavailable. Finite-difference sensitivities remain a reference/fallback path and are not the intended structural production path.

### APPLICATION_SPECIFIC

A numeric `H_app` is application-specific. Project/application accuracy requirements and the actual coupling-window selection belong to the application accuracy contract. There is no universal physically defensible MODFLOW head tolerance.

### RESEARCH_ONLY

RossFast production admission is not required for v1. A RossFast local/terminal-substep tangent is not a substitute for a true accepted whole-window coupling tangent. Energy-balance and solute coupling remain outside this frozen v1 denominator.

### FUTURE_SCOPE

Broader MODFLOW functionality beyond the restricted v1 profile, universal project coverage, deep-vadose implementation, reduced-order production admission, 100k-column benchmarking and more sophisticated adaptive coupling algorithms are not completion blockers unless separately admitted into a future denominator.

## Definitive current evidence

Current canonical contains the admitted production sources:

- `src/runtime/mod_groundwater_coupling_contract.f90` blob `fc598d14eabafcb025bb55621f7b00d6d1816f10`;
- `src/runtime/mod_groundwater_coupling_policy.f90` blob `5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976`;
- `src/runtime/mod_groundwater_exchange_service_contract.f90` blob `f0fc25592624360802713a9487813d119e7dc4e9`;
- `src/runtime/mod_groundwater_interface_mass_ledger.f90` blob `d37f1926dafde9d941939cf4147d799cb7478bfc`;
- `src/runtime/mod_groundwater_predictor_corrector_window.f90` blob `fa2a5a45d558fbaaea242438915cdb7420b6503c`;
- `src/runtime/mod_groundwater_swap_forcing_adapter.f90` blob `f3bf2effebc772b1e3417232d2baabe49ebb8da0`;
- `src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90` blob `649b3587a730d2ae3b0e3b8a512fadc216e202f6`;
- `src/runtime/mod_coupling_application_accuracy_adapter.f90` blob `9212d600e89c85287e9280832c7e0a94befb642e`;
- `src/runtime/mod_coupling_application_accuracy_contract.f90` blob `c07d573d21e7d013ab962c0a9d28102ab7b5cdfc`;
- `src/solver/mod_soil_water_solver_contract.f90` blob `276941d76ba951a89c43899e61fd0532418d8230`.

F-CI56 definitive G04 admission is `c19a04721a05c6a00ba264e7477969807dcb258f`, tree `5342833575484452b34606f8854ff3f5a542e452`. It independently qualifies and canonically admits the restricted predictor-corrector source while expressly making no claim for full direct-groundwater/MODFLOW end-to-end admission, tile-aggregation composition, application-temporal binding composition, response-tangent composition, distributed crash recovery or large-batch throughput.

F-GC20 branch authority is `54dc9cc930468d9f376f596fe2c1b6f45938b59b`, tree `259516aebdc7953ad04e6fb928c31a01e9556815`. It qualifies multi-tile/mixed-component aggregation, no silent fraction normalization, exact `q_gw=-q_swap` and no forced 1:1 mapping, but explicitly has no canonical or end-to-end production admission. Its production source `src/runtime/mod_groundwater_tile_aggregation.f90` is not present on the audited current canonical.

F-GC22 branch authority is `c50f3770ae8e4bee7c276a080be00156218944f1`, tree `3acc6bb6341df0bac3db36c082b501caca14a30e`. It qualifies application/temporal budget separation and no universal project numeric default, but explicitly has no canonical or end-to-end production admission. Its production source `src/runtime/mod_groundwater_accuracy_binding.f90` is not present on the audited current canonical.

The common soil-water contract already exposes first-class `request_interface_sensitivity`, `dh_bottom_dq_bottom`, method provenance and sensitivity backsolve diagnostics. That is a necessary base capability. It does not, by itself, prove the missing accepted whole-window F-GC23 coupling response composition.

F-KT16 proves the frozen generic state/persistence/restart domain. It does not substitute for the missing coupling-specific restart/split-run/replay composition specified by F-GC16.

## Completion dimensions

| Dimension | Verdict | Evidence-based reason |
|---|---|---|
| Typed groundwater interface | PASS | Current canonical typed contract and forcing adapters; G01 preserved by F-RG03. |
| Explicit H/q contract | PASS | Hydraulic head uses explicit datum; residual is `H_SWAP-H_GW`; exact flux pairing is `q_SWAP+q_GW=0`. |
| Transactional exchange | PASS | G02 preserved; checkpoint/trial/candidate/discard/commit semantics are explicit. |
| Two-phase commit | PASS, restricted in-process scope | Prepared groundwater handles and prepared mass-ledger handles support prepare then commit/abort. Distributed/crash transaction recovery is an explicit nonclaim and is not silently claimed here. |
| Accepted exchange provenance | PASS | G04 accepted transfer is derived from the accepted corrector result and candidate lineage, not solver scratch or predictor state. |
| Mass ledger | PASS at admitted G01-G04 scope | Prepared ledger commits once; abort changes no committed exchange; groundwater transfer is exact negative of SWAP transfer. G05 still needs end-to-end proof across adapter/tile composition. |
| Predictor-corrector | PASS | F-CI56 admission; predictor is discarded, corrector starts from the same committed checkpoint, publication occurs after preflight. |
| Generic coupling window | PASS | Typed window only requires finite increasing `t0,t1`; no calendar/day assumption in the coupling contract. `86400` is used only for native cm/day unit conversion. |
| Application accuracy | PASS at contract level | Current canonical separates application requirement and interface policy; no universal `H_app` is claimed. |
| Temporal accuracy binding | FAIL for frozen end-to-end v1 | F-GC22 is owner-qualified but not canonically admitted/composed; its source is absent from current canonical. |
| MultiSWAP composition | FAIL | Frozen F-GC16 reserves explicit direct-groundwater MultiSWAP execution composition; no corresponding completed/admitted G05 production composition is present. |
| Tile aggregation | FAIL for frozen end-to-end v1 | F-GC20 owner qualification exists, but the source is absent current canonical and not composed/admitted with the restricted PC path. |
| No forced 1:1 mapping | PASS architecture | F-GC20 explicitly qualifies multi-tile cells and forbids forced 1:1 mapping; no contrary direct MODFLOW composition appears in the inspected canonical coupling sources. |
| Deep-vadose compatibility | PASS architecture | Frozen profile keeps deep-vadose external to SWAP and does not require its implementation. |
| Solver isolation | PASS | Coupler consumes kernel/typed solver contracts, not HeadCalc internals; source audit found no direct HeadCalc coupling in the inspected repository. |
| Interface sensitivity | FAIL for frozen production composition | Typed sensitivity exists, but F-CI56 explicitly says F-GC23 whole-window response-tangent composition is not admitted. |
| Bounded coupling-cost architecture | PASS | Frozen profile is predictor plus one corrector, two SWAP trajectories normally; finite difference is fallback/reference, not a mandated 6-9-run path. |
| Diagnostics | FAIL for complete v1 composition | PC and ledger diagnostics exist, but application accuracy context, aggregation context, coupling-specific restart and external-adapter end-to-end diagnostics are not yet admitted as one production path. |
| Restart | FAIL for coupling-specific v1 | Generic restart is complete, but frozen coupling-specific accepted-boundary split-run/replay composition is still downstream. |
| Current-canonical preservation | FAIL overall | G01-G04 are preserved. F-GC20/F-GC22 are branch-qualified only; F-GC23+ composition/admission is absent. |

## Source-wide architecture audit

The repository/source audit did not identify a direct `MODFLOW`, `HeadCalc` or `midnight` dependency in the inspected coupling/kernel path. Current canonical coupling code carries generic `[t0,t1]`, typed datum/head/flux contracts, explicit candidate lineage, prepared exchange and prepared ledger publication. `src/adapter` contains no current-canonical groundwater/aquifer adapter. This absence is consistent with G05 and must not be reinterpreted as a proof that the end-to-end adapter already exists elsewhere.

No grep count is used as sole evidence. The completion verdict relies on the positive source contracts above, definitive owner authorities, independent qualification/canonical admissions and F-RG03 denominator status.

## Primary hard gap and six closure obligations

### G05_END_TO_END_DIRECT_GROUNDWATER_COMPOSITION

Frozen requirement: complete the qualified restricted direct-groundwater profile as one production composition without altering G01-G04 semantics.

Why it blocks 100%: F-RG03 explicitly retains G05 in the fixed denominator at `CONTRACT_ONLY_NOT_IMPLEMENTED`; F-CI56 explicitly refuses end-to-end production admission and names downstream missing compositions.

Owner: `groundwater coupler/runtime composition`.

Production physics change: **NO**. Runtime/coupler implementation changes are expected for some obligations.

Independent qualification required: **YES**.

Canonical admission required: **YES**.

Concrete obligations, in dependency order:

1. **SENSITIVITY_GAP / IMPLEMENTATION_GAP**: F-GC23 accepted whole-window response-tangent and one-corrector composition. Do not relabel a local/terminal tangent as a whole-window tangent. Use finite difference only as reference/fallback. If the current Full Richards production authority cannot provide the required semantics without changing a contract owned outside F-GC, stop and record that dependency instead of editing that contract here.
2. **TILE_AGGREGATION_GAP / CANONICAL_ADMISSION_GAP / PRESERVATION_GAP**: consume the qualified F-GC20 primitive in current-canonical G05 composition, preserving exact area-weighted mass and rejecting invalid fractions rather than silently normalizing them.
3. **TEMPORAL_ACCURACY_GAP / CANONICAL_ADMISSION_GAP / PRESERVATION_GAP**: consume the qualified F-GC22 application/temporal binding in current-canonical G05 composition, without introducing universal numeric defaults or aliasing temporal error to interface tolerance.
4. **RESTART_GAP / IMPLEMENTATION_GAP**: qualify accepted coupling-window restart/split-run/replay. A prepared-but-uncommitted exchange must never reappear as accepted after restart; rejected scratch is not persistent state.
5. **MULTISWAP_GAP / DIAGNOSTICS_GAP / IMPLEMENTATION_GAP**: compose direct coupling with MultiSWAP/tile execution, deterministic aggregation, transaction isolation and complete per-window diagnostics. No 100k benchmark is required for this closure unless a separate performance denominator requires it.
6. **INTERFACE_CONTRACT_GAP / IMPLEMENTATION_GAP / QUALIFICATION_GAP / CANONICAL_ADMISSION_GAP**: provide an external aquifer/MODFLOW adapter conformance path and restricted end-to-end production admission proving exact exchange mass, bounded head residual under the active application contract, generic coupling windows and preservation on then-current canonical.

These six obligations are not six new frozen denominator rows. They are the minimal technical closure of the single existing G05 blocker.

## Dependency-ordered closure route

`G01-G04 frozen/preserved` -> `F-GC23 whole-window tangent composition` -> `G05 integration of F-GC20 + F-GC22 + tangent` -> `coupling restart/replay + MultiSWAP/diagnostics` -> `external aquifer adapter conformance` -> `independent end-to-end qualification` -> `canonical admission` -> `post-admission preservation` -> `F-RG rebaseline`.

F-RG03 recommends F-GC24 as the direct-groundwater composition lane. That recommendation is treated as the current program-level integration owner after the bounded F-GC23 dependency is closed. The older F-GC16 numbering plan remains valuable evidence of semantic ownership but does not override the later F-RG03 execution authority.

## Hard-blocker test

No evidence was found that accepted G01-G04 exchange itself can lose mass, publish a rejected candidate, use ambiguous accepted-transfer provenance, mutate committed state during predictor trials, hard-code daily/midnight windows, force 1:1 cell/column mapping, or depend directly on HeadCalc internals. Those blockers are therefore not asserted.

100% is nevertheless forbidden because the frozen G05 end-to-end capability is not implemented, independently qualified, canonically admitted and preserved. Material downstream branch-qualified capabilities F-GC20 and F-GC22 have not been reconciled into current-canonical production composition, required whole-window sensitivity composition is missing, and coupling-specific restart/MultiSWAP/adapter end-to-end admission remains open.

## Final outcome

`GROUNDWATER_COUPLING_V1_FINAL_CLOSURE_GAPS_IDENTIFIED`

Do not emit `QUALIFIED_GROUNDWATER_COUPLING_V1_100_PERCENT_COMPLETE` from this head.
