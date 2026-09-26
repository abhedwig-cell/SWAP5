# F-PE-APPROX02 A2B preregistration — conservative Richards convergence envelope

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX02 — practical Richards solve-effort frontier`

Predecessor candidate:
`A2 (1e-4) — REJECTED_COUPLED_ROBUSTNESS`

## Rationale

The 1e-4 A2 setting delivered large direct solver gains and small state/flux errors, but failed the replicated live SWAP + MODFLOW6 gate in two of three independent jobs.

The existing 12-case frontier contains a substantially more conservative setting that still delivers material performance gain.

## Candidate A2B

A2B changes only these local Richards convergence tolerances:

- head absolute tolerance: `1e-6`;
- head relative tolerance: `1e-6`;
- compartment balance tolerance: `1e-6`;
- total balance tolerance: `1e-6`.

Unchanged:

- ponding tolerance remains exact/current;
- canonical transaction mass tolerance remains exact/current;
- retry policy remains exact/current;
- timestep/temporal policy remains exact/current;
- iteration and backtracking caps remain exact/current;
- A1 tangent caching is not part of the A2B qualification comparison.

Default production behavior remains exact.

## Existing one-step evidence

This corresponds to the former `1e6` matrix candidate.

Across B01/B12/O05/O14 wet/mid/dry:

- all 12 cases converged;
- median direct solver speedup approximately 44.7%;
- minimum speedup approximately 36%;
- worst relative pressure-head deviation approximately `1.2e-6`;
- worst relative bottom-flux deviation approximately `1.0e-6`;
- worst relative water-content deviation approximately `6.7e-8`;
- direct-solver mass residual remained zero in the qualified fixture.

## Required gates

A2B must independently pass:

1. 20-step accepted-state trajectory matrix;
2. production application sequence with canonical mass accounting;
3. three independent live SWAP + MODFLOW6 end-to-end jobs;
4. explicit exact-default preservation if any production configuration surface is added.

## Coupled rejection rule

A2B is rejected if any replicated live MODFLOW6 job shows:

- a new SWAP trial failure;
- a new coupling convergence failure;
- materially increased coupled iteration count;
- unexplained endpoint/ledger drift;
- or loss of exact mass/default behavior.

A single successful replica is not sufficient if other independent replicas fail.

## Admission boundary

Passing these research gates qualifies an envelope.

A production opt-in configuration surface may only be added after the envelope is qualified and must expose explicit approximate provenance while leaving default exact behavior unchanged.
