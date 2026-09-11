# F-TB01 — SWAP5 Scientific Verification, Qualification & Release Testbank Architecture

## Status and scope

This document defines the architecture of the SWAP5 testbank. F-TB01 is an architecture, inventory and consolidation workunit. It does not change production physics, solver semantics, runtime semantics, existing scientific tolerances or canonical production behaviour.

Frozen source authority for this workunit:

- repository: `abhedwig-cell/SWAP5`
- source ref at fork: `integration/f-ci-canonical`
- source commit: `3c5f5bd3686e1632058b906be21abd73883e30ef`
- source tree: `6baaf40271497db831698c5a01de355b5d296dbe`
- work branch: `work/f-tb01-swap5-testbank-architecture`

The testbank is an index and execution architecture over scientific cases, qualification evidence and regression assets. Existing F-VQ/F-MQ/F-CI and other workunit tests remain valid at their own frozen authorities; F-TB01 does not make directory location an admission authority and does not relocate them merely for taxonomy.

## Three distinct evidence purposes

The testbank SHALL keep these purposes separate:

1. **Historical qualification** — evidence is valid only for the exact candidate source authority and exact frozen test matrix that were qualified.
2. **Moving-current preservation regression** — a later canonical postimage is explicitly rebound to a previously qualified capability by a preservation case/matrix and, where needed, a reviewed delta-revalidation.
3. **Broad release regression** — an integrated release profile checks system quality across admitted capabilities; it does not retroactively redefine historical admission evidence.

A green historical exact-source admission test SHALL NOT automatically become a moving-current preservation claim. `source_authority`, `test_matrix_authority`, `evidence_authority`, and `admission_purpose` are separate fields and separate authorities. This prevents a source head, a workflow result and a governance closeout from being conflated.

## Architectural layers

### TB-L0 — Mathematical primitives
Interpolation, inverses, quadrature/integration, derivatives, limiters and constitutive helpers. Oracles include analytical identities, finite-difference derivative checks, continuity, monotonicity, limiting behaviour and finite-value checks.

### TB-L1 — Soil-hydraulic constitutive behaviour
All supported hydraulic families: `theta(h)`, `C(h)`, `C ≈ dtheta/dh`, `K(h)`, `dK/dh`, inverse pressure heads, dry/saturation limits, parameter boundaries and explicit continuity/discontinuity classification. Existing hydraulic/constitutive qualification assets are to be registered and reused, not blindly rewritten.

### TB-L2 — Isolated physical processes
Reference/potential ET, surface evaporation, root uptake, irrigation, drainage, snow, soil temperature/frost, macropores, interception, surface water/runoff, crop/WOFOST and future optional processes. Each case identifies parameters, forcing, persistent state, outputs, scratch, transaction semantics and applicable mass/energy accounting.

### TB-L3 — Soil-water solver verification
Full Richards reference and any future coarse/reduced/RossFast/other solver behind the common soil-water solver contract. Coverage includes exact/manufactured/reference solutions, temporal/spatial refinement, nonlinear convergence, Jacobian checks, linear solver behaviour, fluxes, boundary transitions, response tangents and the hard mass gate.

### TB-L4 — Kernel and transaction semantics
Checkpoint → trial/retry → commit or rollback. Rejected trials SHALL NOT mutate committed physical state, time/revision/lineage or committed ledgers. Accepted work is committed exactly once. Cases cover replay, retry, stale checkpoint/candidate rejection and generic `[t0,t1]` intervals.

### TB-L5 — Persistence and restart
Compare a continuous run with run → committed boundary → externalize → destroy runtime → reconstruct → restore → continue. Compare physical state, generic time, revision, lineage, water ledger, optional state, schema/layout identity and deterministic continuation.

### TB-L6 — Integrated column combinations
Pairwise and risk-based combinations such as rainfall×infiltration, ET×root uptake, root uptake×groundwater, drainage×groundwater, evaporation×ponding, snow×infiltration, frost×hydraulics, macropore×surface boundary and crop×ET×root uptake. Coverage is combinatorial/risk-based, not brute-force Cartesian enumeration.

### TB-L7 — SWAP 4.3.1 source-bound scientific/reference comparison
Legacy comparisons require frozen input/source provenance and one explicit difference class: `EXACT_EQUIVALENCE_EXPECTED`, `NUMERICAL_EQUIVALENCE_EXPECTED`, `INTENTIONAL_PHYSICS_CHANGE`, `LEGACY_DEFECT_CORRECTED`, or `NOT_COMPARABLE`. A known legacy defect SHALL NOT be frozen as a production golden result merely because it is reproducible.

### TB-L8 — Groundwater and coupling
Dummy aquifer, prescribed groundwater head, flux-driven coupling, predictor/corrector, rollback, coupling-window refinement, head/interface residuals, response tangents, multiple surface tiles per groundwater cell and optional deep-vadose transfer. Interface water conservation is hard: `q_SWAP + q_GW = 0` under the qualified sign/ledger convention. A nonzero head residual is allowed only under an explicitly qualified application-specific tolerance.

### TB-L9 — MultiSWAP
The same logical column is exercised standalone, serialized and parallel. Scale points include 1, small/irregular groups, thousands and eventually 100k+ logical columns. Worker counts include 1/2/4 and later platform-relevant counts. Order attacks include identity, reverse, shuffled, odd/even and changing batch boundaries. Scientific results SHALL be independent of scheduling/order within the defined numerical identity policy.

### TB-L10 — Performance and bounded cost
Measure wall/CPU time, accepted steps, nonlinear iterations, solves, factorisations/backsolves, retries/fallbacks, constitutive evaluations, allocations, peak memory, bytes/column, throughput and tail latency. Difficult-column profiles include heavy clay/B12, coarse sand/O5, O13, near-saturation and dry↔wet transitions. Correctness and mass gates remain independent of performance success.

### TB-L11 — Robustness/adversarial/property testing
Extreme valid dry/saturated states, abrupt rain/evaporation, rapidly varying groundwater, thin layers, material transitions and extreme valid hydraulic parameters. Required properties include finite values/no NaN, physical state bounds, hard mass closure, rejected-trial immutability and deterministic replay where required.

### TB-L12 — Release qualification
A compact mandatory release suite assembled from immutable registered cases/matrices. Release qualification reports exact source, profile, compiler/platform, actual case counts and failures. It does not fabricate coverage totals or substitute for independent scientific qualification.

## Horizontal contracts

The following apply across layers:

- **Mass conservation is hard.** No numerical/performance profile may relax it.
- **Time is generic.** Test definitions use `[t0,t1]`; calendar boundaries appear only when a physical process explicitly requires them.
- **Physical configuration and numerical policy are separate dimensions.** A speed policy cannot silently change physics.
- **State authority is explicit.** Persistent state, immutable parameters, forcing, numerical configuration, scratch and results remain distinct categories.
- **Optional functionality scales with use.** Cases SHALL expose accidental per-column state/scratch allocation for inactive options.
- **Diagnostics are observable evidence, not a second state authority.** Solver mode, retries, fallback, iteration cost, mass residual and transaction outcome can be asserted without becoming restart state.
- **Alternative solvers qualify behind the common soil-water interface.** Full Richards remains the reference mode; a new solver is classified `ADMITTED`, `ADMITTED_WITH_BOUNDED_FALLBACK`, `UNSUPPORTED`, or `FAIL` for each qualified scope.

## Proposed repository layout

```text
testbank/
  cases/          # future case payloads where appropriate
  fixtures/       # small immutable test fixtures
  manifests/      # frozen case/matrix registries
  oracles/        # independent/reference material where appropriate
  reports/        # schemas/examples, not mutable canonical evidence
  runners/        # orchestration/validation; no kernel I/O coupling
  schema/         # machine-readable contracts

docs/testbank/    # architecture, governance, inventory and closeout
```

Existing tests can remain under `tests/fvq`, `tests/fmq`, `tests/fci`, `tests/runtime`, `tests/fmr`, `tests/fpm`, `tests/fsi`, etc. Registry entries reference exact paths and evidence authority.

## Implementation language boundary

Fortran remains appropriate for behaviour checks close to physics/solver contracts. Python (stdlib preferred for the base registry validator) is appropriate for orchestration, report validation, statistics and performance aggregation. Shell/CI composes execution. Testbank I/O never leaks into the computational kernel.

## Qualification rule

F-TB01 qualifies the **architecture and prototype mechanics**, not the entire scientific case catalog. Building the full catalog is incremental future work. No claim of “fully tested” is valid unless its coverage model, matrix version, oracles, tolerances and exact evidence are named.