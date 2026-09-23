# ROM-PRACTICAL P4: numerical implementation status

Date: 2026-09-23

Status: LOCAL_STABILITY_CHARACTERIZED; PINNED_SOURCE_CI_AND_SAME_HOST_REFERENCE_COMPARISON_OPEN.

## Frozen research scope

S4 retains boundaries [0,20,40,80,160] cm. G8 retains boundaries
[0,80,100,120,130,140,150,155,160] cm. CURRENT_LAYER_FACE,
material parameters and the 60-day P3 forcing are unchanged.

P4's primary numerical target remains classical RK4 at dt=0.01 day.
The preregistered dt=0.005 day route remains its numerical comparator.
A successful comparator is not a retrospective replacement of a failed primary target.

The implemented P3 groundwater HOLD segment prescribes bottom flux k0;
it does not hold the bottom pressure head at its initial value.
The workload is a controlled daily experiment, not observed weather,
seasonal validation or an operational groundwater-coupling test.

## Executed local evidence

Source blob: 5f8f96300523fb8a1534b3cc2f1c159921c95a05.
Material authority: ROM_PRACTICAL_P2A_MATERIALS.json.
Reproducibility and numerical details: ROM_PRACTICAL_P4_LOCAL_SCREEN.json.

The source was compiled with GNU Fortran 14.2.0 at O2, runtime checks
and floating-point traps. All eight purpose/material combinations were
executed at both preregistered steps.

| Purpose/material | RK4 0.01 day | RK4 0.005 day |
| --- | --- | --- |
| S4 / B02, B05, B11, B16 | 4 of 4 complete | 4 of 4 complete |
| G8 / B02, B11, B16 | 3 of 3 complete | 3 of 3 complete |
| G8 / B05 | Numerical blocking | Complete |

A complete case contains both 60-day histories. B05 at the primary step
completed GD01 but failed during GD02, day 1, substep 4, RK4 stage 4.
That partial case is not qualified. The failing stage left the unchanged
qualified constitutive domain; the implementation rejects rather than clips it.

All complete local runs satisfy the preregistered 1e-8 cm water-ledger gate.
The largest observed residual was approximately 3.20e-10 cm.

Local initial-state linearization is consistent with the failure mechanism:
for B05/GD02, the RK4 amplification polynomial exceeds unity at dt=0.01
but is below unity at dt=0.005. This is a local explanation, not a global
nonlinear stability proof. B02 completing under RK4 does not prove that
compilation alone solved Heun blocking, since the integrator also changed.

The primary all-case robustness objective is not supported by these local
runs. The half-step gives positive bounded-panel evidence that the frozen
reduced equations can be integrated without adding states or closure physics.
It does not establish application validity or broad numerical robustness.

## Remaining gates and infrastructure status

The complete qualification workflow performs pinned Python/Fortran equation
conformance, full-versus-half hydrological metrics, same-runner R64/R128
reference runs, repeated wall/CPU timing and a rerun of the Python Heun baseline.
It stores numerical failure separately from infrastructure failure.

Run 35903898972 stopped during source-identity checking, before numerical
qualification. No scientific failure or speed ratio is inferred from that run.
Run 35904977577 adds per-file expected/actual identity diagnostics while
retaining every frozen identity check. At the last status check it was queued.
The cause of the original identity-check failure has not yet been resolved.

Local transcribed-expression checks passed, but they are not substituted for
the full pinned-source conformance gate in CI. No Richards execution was
performed on the local host. Local timings therefore cannot be divided by
old CI Richards timings to manufacture a speedup.

P4 is not declared closed. The remaining comparison is computational and
provenance qualification, not permission to change representation or forcing.
P-ROM-ET remains unopened. Production admission and application acceptance
remain outside this workstream.
