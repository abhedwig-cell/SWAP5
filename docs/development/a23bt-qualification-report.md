# A23BT Qualification Report

## Result

**PASS**: reporting/output progression is separated from column continuation state on the qualified Hupsel/B1.6 transaction route, legacy output emission is suppressed during trials, and reporting-driven accumulator reset controls are explicit worker inputs rather than global dependencies.

Status: `PASS_REPORTING_STATE_SEPARATION_AND_TRIAL_OUTPUT_SUPPRESSION / PRODUCTION_REPORTING_DELIVERY_PENDING / PHYSICAL_BACKEND_SERIAL_ONLY`.

## Scope

A23BT builds directly on A23BS. It does not modify Richards physics, constitutive relations, Jacobian formulas, timestep/retry policy, or selective step doubling. The physical backend remains the serialized B1.6 bridge.

The qualified reference configuration is Hupsel with `NPRINTDAY=1`, `FLPRINTDT=.false.` and whole-day legacy adapter boundaries.

## Changes

1. Removed the saved `tcumold` reporting cursor from dynamic worker execution.
2. Moved dynamic reporting counters and flags into `worker%reporting`.
3. Added explicit `reset_intermediate` and `reset_cumulative` reporting reset controls.
4. `integral` and `solute` no longer read global `flzerointr`/`flzerocumu` on the transformed worker source.
5. Suppressed standard legacy output dispatch whenever the transaction worker is present.
6. Kept reporting progression out of `hupsel_column_state_t`; the shim is 56 B per worker.

## Physical qualification

O0 and O2 are byte-identical. The physical log SHA-256 is `5520a76c3ccffe3b3a03af3867a6544b0147ddedd817385b76b91359f1043e63`. The endpoint is the exact B1.6 continuation state `4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`.

| Metric | Result |
|---|---:|
| accepted storage | 77.011710672204643 cm |
| mass residual | -1.7872350177583485e-7 cm |
| hard B1.6 mass criterion | 1.0e-6 cm |
| internal retries total / accepted | 20 / 10 |
| HeadCalc calls total / accepted | 162 / 81 |
| Newton iterations total / accepted | 956 / 478 |
| Jacobian builds total / accepted | 956 / 478 |
| linear solves total / accepted | 956 / 478 |
| backtracking total / accepted | 1350 / 675 |

The reporting-poison test deliberately corrupts legacy `nprintcount`, `cntper`, output-date counters, output flags, `flzerointr`, `flzerocumu`, worker reporting state, worker time events, timestep controls and solver scratch. Two logical columns then execute in reverse order through the same legacy singleton. Both state and diagnostics reproduce their serial references exactly.

## Output-side-effect gate

The always-sampled full + two-half transaction leaves the opened `.BAL` and `.BLC` file sizes unchanged. The transformed source bypasses the standard legacy output dispatch whenever a worker is present. Rejected and shadow trials therefore cannot write accepted legacy output.

This does **not** claim the legacy adapter is entirely I/O-free. Input-side legacy file operations may remain; the new kernel contract itself remains I/O-independent.

## Worker qualification

Eight OpenMP worker contexts execute 1,000 independent mutation cycles each: **8,000 checks, 0 failures**. Solver scratch remains 3,292 B per worker and the reporting shim is 56 B per worker. No reporting progression bytes are added to persistent column continuation state.

## Jacobian

`jacobian_F()` is byte-identical to A23BS. SHA-256: `83a0405484bb11b97a4ad6d8eed908f6a6b478a748c2b9056eba44299b0e427a`.

## Production holds

- no committed-results reporting service/runtime cursor has yet been implemented;
- subdaily output schedules are not qualified;
- the physical B1.6 backend is still serialized;
- legacy input-side I/O and non-worker reporting compatibility code remain outside this cut.

## Next

A23BU should leave reporting delivery outside the kernel and address the next remaining **physics-relevant** process/progression singleton cluster rather than further expanding output bookkeeping inside column state.
