# F-TB01 — Tolerance Governance

## Rule

Every non-exact pass/fail tolerance is a governed scientific/numerical object. A bare number in a test is insufficient evidence.

Required metadata for every non-exact tolerance:

- stable tolerance ID and version;
- class;
- quantity and unit;
- comparison meaning (absolute, relative, mixed, norm, percentile, etc.);
- numerical/physical scope;
- rationale;
- provenance/source authority;
- owner/governance authority;
- qualification evidence;
- exclusions and boundary behaviour.

## Classes

- `FP_IDENTITY` — roundoff/representation identity, compiler/platform-scoped where needed.
- `NUMERICAL_SOLVER` — discretisation, nonlinear/linear solver or derivative/refinement tolerance.
- `SCIENTIFIC_COMPARISON` — scientifically justified difference against an oracle/reference.
- `APPLICATION` — application-class requirement such as an explicitly justified groundwater-head accuracy budget.
- `COUPLING` — interface convergence tolerance; flux conservation remains separately hard.

## Hard versus qualified-soft checks

Water mass conservation is not made optional by a tolerance class. A mass gate may define a machine-precision/ledger-closure evaluation rule needed to distinguish representational roundoff from lost water, but profiles may not widen it to trade correctness for speed.

Groundwater coupling distinguishes:

- flux/interface conservation: hard under the qualified sign and ledger convention;
- head residual: qualified-soft only when a concrete application class and independent accuracy requirement justify it.

## Anti-target-leakage rule

A tolerance SHALL NOT be selected after looking at candidate errors merely to make the candidate pass. Candidate observations can trigger characterization, but final limits require independent rationale or held-out evidence. Tuning and qualification datasets/matrices are distinct when tuning is involved.

## Versioning

Changing a threshold, norm, unit, scope or rationale creates a new tolerance version and therefore a new frozen test-matrix authority. Historical qualification remains bound to the old tolerance. A later canonical run under a new tolerance is new evidence, not a reinterpretation of old evidence.

## Performance thresholds

Performance thresholds are governed separately from correctness tolerances. They require hardware/compiler/runtime metadata, warm-up policy, repeat count, aggregation statistic, noise class and timeout policy. A performance PASS cannot override any scientific, determinism, transaction or mass FAIL.