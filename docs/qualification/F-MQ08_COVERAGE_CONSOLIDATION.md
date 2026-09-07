# F-MQ08 Qualification coverage consolidation

Status: `PASS_COVERAGE_CONSOLIDATED / NO_REAL_PHYSICS_OR_PRODUCTION_RUNTIME_CLAIM`

## Purpose

F-MQ08 converts the immutable F-MQ01 requirements matrix into a current, derived qualification-coverage view. It does not rewrite F-MQ01 history. This prevents a later test result from silently changing the original requirement, minimum scale, frequency or dependency definition.

No production source, solver physics, numerical policy or production MultiSWAP runtime is changed.

## Baselines pinned

The requirements baseline is the exact Git blob of:

`tests/multiswap/qualification_matrix.json`

Blob SHA: `4b53b71375833ae94e788da8b6eab0dc2e6c1dad`.

The F-MQ qualification lineage consolidated here is through F-MQ07 commit:

`eaaad532ddab92c359c44996940db295e50212a3`.

During consolidation the current canonical integration line was re-read. It had advanced to F-CI06 commit:

`4c99d9c583c2f82a542e8d8408e39411e23597aa`.

F-CI06 materially improves the prerequisite situation because a B1.10 water checkpoint/clone postimage now exists. F-MQ08 does not infer from that that a real event-local fixture is ready: generic short physical continuation and complete unrounded accepted-interval mass accounting have not yet been admitted by F-MQ.

## Coverage dimensions

Every one of the 35 F-MQ01 requirements now has three independent status dimensions:

1. `synthetic_executable`: directly exercised by F-MQ deterministic qualification infrastructure;
2. `real_physics_executable`: executable against an admitted current B1.10/SWAP5 reference-derived physical fixture with the hard mass gate;
3. `production_runtime_qualified`: passed against the production MultiSWAP/coupling runtime itself.

These dimensions must not be collapsed into one PASS flag.

## Current result

The derived snapshot contains exactly 35 entries:

- 26 have an executable synthetic qualification path;
- 0 currently have an F-MQ-admitted real-physics execution path;
- 0 qualify a production MultiSWAP runtime;
- 2 remain in the separate performance lane;
- 1 remains the long scientific-regression lane.

The 26 synthetic entries comprise:

- R01-R08 from F-MQ02;
- P02-P09 except P01, plus P12, P13, P15, P18 and P19 from F-MQ02/F-MQ05;
- D01-D02 from F-MQ06;
- P20-P22 from F-MQ07.

P05 also records that F-CI06 now provides a canonical B1.10 water checkpoint/clone prerequisite, but this does not by itself create a reference-derived physical fixture.

## Dependency grouping

The remaining work separates cleanly.

### F-CI/F-KT and reference-fixture path

P01, P06-P08, P10-P13, P16-P19, D01-D02 and S01 still need some combination of a canonical real physical continuation seam, admitted event-local reference evidence and complete unrounded mass accounting.

P14 needs a qualified persistent-state layout/introspection contract for optional modules.

### F-MR

R01-R08 and production versions of scheduler, worker, batch, diagnostics, isolation and difficult-column properties remain production-runtime qualification work. Synthetic F-MQ success is a contract oracle for F-MR, not a substitute for F-MR.

### F-SI / coupling runtime

P20-P22 are synthetically closed as contracts but real tile/coupling execution remains with F-SI/F-MR and the canonical physical seam.

### Performance

PFX01 and PFX02 remain separate from correctness. MP measurement vocabulary and isolated-runner contracts may be reused. Wall-clock timing is not promoted to a shared-CI correctness gate.

## F-CI06 observation

F-CI06 adds `mod_b1_10_water_checkpoint` and therefore removes part of the earlier state-capture uncertainty. It does not yet justify marking P10/P11/P16/P17 real-executable in F-MQ. F-MQ requires the full chain:

checkpoint -> admitted short generic physical continuation -> endpoint -> complete unrounded accepted mass accounting -> reproducible reference record -> F-MQ04c admission -> F-MQ03 fixture.

Until that chain closes, real-physics status remains false.

## Gate

Repository command:

`python3 tests/multiswap/run_fmq08_gate.py`

The gate verifies:

- exact immutable F-MQ01 blob identity;
- one and only one coverage row for every F-MQ01 requirement;
- exact derived summary counts;
- F-CI06 checkpoint availability cannot falsely promote real-physics status;
- historical evidence cannot promote current production qualification;
- coupling and difficult-column results remain correctly scoped;
- performance entries remain outside correctness status.

## Architecture assessment

F-MQ08 changes no production code. It strengthens invariant 30 by making qualification state explicit and prevents accidental violations of invariants 13, 16, 23, 24, 25 and 26 through overclaiming.

The next F-MQ work should now be chosen from the uncovered classes rather than by adding more overlapping synthetic harnesses.
