# F-PE18 — Richards workspace lifetime MEASURE evidence

Date: 2026-09-16

Status: `MEASURE_MICRO_COMPLETE_B_CANDIDATE_FULL_PATH_PENDING`

## Authority and execution identity

F-PE18 branch:

`work/f-pe18-richards-workspace-lifetime-measurement`

Base canonical at workunit start:

`8f592dcc1651913b2b24356fd6379e7fafa817a4`

Measurement head:

`fe326948a0428168ac7eee07e74923d2c6f5b65b`

Draft PR:

`#156 — F-PE18: measure current Richards workspace lifetime overhead`

Measurement workflow:

- run: `35076839295`
- job: `104731163664`
- conclusion: `success`
- runner: GitHub hosted Ubuntu 24.04.5, image `ubuntu-24.04` version `20260907.300.1`
- compiler: GNU Fortran 13.3.0
- Python: 3.12.3
- PR merge-test head used by GitHub Actions: `b929ae9f2ff9d84cafbda44fd31c547780eec590`

Artifact:

- name: `fpe18-richards-workspace-lifetime`
- artifact id: `10438082983`
- ZIP SHA-256: `4a8b98beb980a8c137d69bc4498e03675efd15333ef336bbece361e6264c7aa7`
- size: 3720 bytes

The artifact contains raw paired observations, summary JSON, strict-build smoke output and runner metadata.

## Measurement semantics

The executable uses the production modules:

- `src/solver/mod_soil_water_solver_contract.f90`
- `src/solver/mod_reference_richards_workspace.f90`

Two arms are compared in separate processes:

- `fresh`: a call-local `reference_richards_workspace_t` is initialized on every cycle and its allocatable components are released through normal scope-exit lifetime, matching the present typed-adapter lifetime pattern;
- `reuse`: one same-shape workspace survives across cycles and `initialize_reference_workspace()` performs reset without reallocating its normal compact payload.

The reuse arm is warmed before the timed section. The result therefore characterizes the avoidable workspace-lifecycle micro-cost, not startup cost.

Qualification checks before/within timing:

- strict `-O0 -g -fcheck=all -fbacktrace` smoke for both arms: PASS;
- O0 and O2 timed builds;
- three active-node profiles;
- four paired rounds per profile;
- balanced process order `fresh/reuse | reuse/fresh | fresh/reuse | reuse/fresh`;
- payload identity between arms: PASS for every profile;
- reset-touch identity: PASS for every profile.

The measurement runner deliberately does not require reuse to be faster. Functional consistency is the only pass/fail condition.

## Results

| Opt | Nodes | Calls | Payload bytes | Fresh median wall s | Reuse median wall s | Fresh / reuse | Reuse wall reduction | Reuse faster rounds |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| O0 | 20 | 40000 | 3948 | 0.047925007 | 0.012803093 | 3.743237 | 73.285% | 4/4 |
| O0 | 100 | 8000 | 19628 | 0.019564503 | 0.012247035 | 1.597489 | 37.402% | 4/4 |
| O0 | 500 | 1600 | 98028 | 0.012225149 | 0.010844514 | 1.127312 | 11.293% | 4/4 |
| O2 | 20 | 40000 | 3948 | 0.026852119 | 0.003893120 | 6.897327 | 85.502% | 4/4 |
| O2 | 100 | 8000 | 19628 | 0.006762759 | 0.001991464 | 3.395873 | 70.552% | 4/4 |
| O2 | 500 | 1600 | 98028 | 0.003877831 | 0.002737031 | 1.416802 | 29.419% | 4/4 |

CPU medians track the wall-time result closely:

| Opt | Nodes | Fresh median CPU s | Reuse median CPU s |
| --- | ---: | ---: | ---: |
| O0 | 20 | 0.0479320 | 0.0128130 |
| O0 | 100 | 0.0195750 | 0.0122530 |
| O0 | 500 | 0.0122360 | 0.0108350 |
| O2 | 20 | 0.0268455 | 0.0039015 |
| O2 | 100 | 0.0067630 | 0.0020000 |
| O2 | 500 | 0.0038870 | 0.0027440 |

Workflow terminal assertions:

```text
FPE18_PAYLOAD_IDENTITY=PASS
FPE18_RESET_TOUCH_ZERO=PASS
FPE18_MEASUREMENT_COMPLETE=PASS
FPE18_PRODUCTION_SPEEDUP_CLAIM=NOT_MADE
```

## Interpretation

The static hotspot is now experimentally confirmed at the workspace-lifecycle level.

Same-shape reuse materially reduces the isolated initialize/reset/lifetime cost on this runner for all measured active-node sizes at both optimization levels. The direction is uniform across all 24 paired profile-round combinations represented by the six profile summaries.

The effect is largest for small workspaces because allocator/lifetime overhead is a larger fraction of the measured cycle. It remains measurable at 500 active nodes.

This evidence is deliberately narrower than a solver or model performance claim. It does not measure:

- HeadCalc cost;
- constitutive-provider cost;
- request/provider materialization;
- nonlinear iterations;
- transaction orchestration;
- complete task-2 cost;
- full SWAP wall time;
- MultiSWAP throughput.

Therefore the large microbenchmark ratios must not be quoted as expected SWAP5 speedups.

## MEASURE classification

The microbenchmark rejects `NO_MATERIAL_HOTSPOT` for the isolated workspace-lifecycle operation.

Current classification:

`B_EXACT_LIFETIME_CANDIDATE — MICROBENCHMARK_CONFIRMED, FULL_PATH_PENDING`

The candidate is exact-semantics in concept because the proposed performance surface is allocation lifetime only. The numerical workspace contents are already reset on every solve by the existing production initialization contract.

This classification does **not** authorize a production mutation yet. Before IMPLEMENT, F-PE18 requires a source-bound full Richards A/B that proves:

1. fresh and reused workspace ownership produce identical scientific solver results;
2. solver route, iterations, mass result and relevant diagnostics remain identical;
3. reuse changes only scratch lifetime, never accepted physical state or transaction ownership;
4. the full solver path shows a measurable benefit large enough to justify the ownership change, or else the workunit closes without production mutation.

## Next permitted action

Use the existing F-SI24 nonlinear B1.10 Richards fixture as the full-path scientific basis. Recover its authoritative invocation parameters/evidence rather than inventing a new hydraulic case. Build a measurement-only fresh-versus-reused workspace harness from that fixture and persist equivalence before considering any `src/` change.
