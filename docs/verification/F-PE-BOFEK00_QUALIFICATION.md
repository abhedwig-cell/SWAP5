# F-PE-BOFEK00 — wet-regime numerical authority qualification

Date: 2026-09-28

Canonical preimage:
`integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

Decision:
`DEFECT_CONFIRMED_CURRENT_REFERENCE`

Admission status:
`QUALIFIED_ADMISSION_CANDIDATE_FIXED_K_DYNAMIC_TOP_SWKIMPL0`

## Historical authority

Recovered through PR #161 and
`docs/verification/F-AR01_LEGACY_ZIP_RECONCILIATION.md`.

Historical package:

- `SWAP_4.3.1_ponding_jacobian_patch_for_Marius.zip`
- ZIP SHA-256 `e0403c4387742cc9a6819729d80b09ba3175579cedf3ae8ed47030cedc930d07`
- historical core-patch SHA-256 `101cd0edd9e22f494582b5536cd82ccd849d2f881c20cda3cf224f2a63e4e1ee`

PR #161 established two separate findings in `headcalc.f90` and
`boundtop.f90`: an incomplete wet top-boundary Jacobian and a
timestep-dependent branch decision before the analytical linear-runoff
solution. The package was explicitly not admission-ready and was not part of
B1.11.

The historical ZIP payload is not materialized in current repository
authority. BOFEK00 therefore does not claim byte-for-byte replay of that
historical patch. It independently reproduces both mechanisms on current
canonical source.

## Current-authority defect

Current paths:

- `src/legacy/b1_10_port/headcalc.f90`
- `src/solver/mod_b110_dynamic_top_boundary_provider.f90`
- `src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90`
- `src/solver/mod_soil_water_solver_contract.f90`

### Jacobian

On the fixed-conductivity head-boundary route the boundary residual is

```
R = -K * ((Hs(h1)-h1)/d + 1)
```

and therefore

```
dR/dh1 = K/d * (1-dHs/dh1).
```

The canonical preimage instead adds `K/d`, equivalent to assuming
`dHs/dh1=0`.

The preregistered finite-difference gate at current canonical preimage found:

- ponded no-runoff: FD/correct derivative approximately `9.09090909`;
  canonical term `10`;
- active linear runoff: FD/correct derivative approximately `9.16666667`;
  canonical term `10`.

The immutable pre-fix reproduction is GitHub Actions run
`36402438433`, head
`354892af8bb2cd994d1c305ee542b5ddadf1840d`, conclusion `SUCCESS`.

### Branch selection

The canonical provider computes current runoff from the incoming Newton
candidate and compares its absolute depth with
`B110_DYN_TOP_RUNOFF_ZERO_CM = 1e-6 cm` before entering the analytical
linear-runoff solution.

For the preregistered controlled state with candidate ponding excess
`0.01 cm` and runoff resistance `0.1 day`:

- `dt=1e-6 day` gives candidate runoff `1e-7 cm` and selects no-runoff;
- `dt=1e-4 day` gives candidate runoff `1e-5 cm` and selects analytical runoff.

The active analytical solution exists for both. Therefore branch choice is
timestep-dependent before that analytical solve.

## Correction candidate

The candidate is intentionally small.

1. The top-boundary result carries
   `surface_head_dpressure_head_top` plus an availability flag.
2. The dynamic provider publishes the analytical derivative on the qualified
   fixed-top-conductivity head branches.
3. The solver adapter transports that derivative.
4. `headcalc` uses
   `K/d * (1-dHs/dh1)` for the dynamic head boundary.
5. Once the no-runoff analytical solution exceeds the runoff threshold, the
   supported `RSROEXP=1` route enters the bounded analytical linear-runoff
   solution directly instead of consulting the incoming Newton candidate
   through the absolute runoff-depth gate.

No `DTMIN`, `DTMAX`, `NUMBIT_CRIT`, `FACT_DT_INCREASE`,
`FACT_DT_DECREASE`, retry, tolerance or mass-balance policy is changed.

## Fixed-conductivity scope

The independent Jacobian qualification is for the fixed top-node
conductivity route. This is the route actually bound by the current
serialized Reference runtime for its dynamic top-boundary evaporation paths:
the runtime evaluates conductivity at the accepted/base top head and supplies
that fixed value to the provider for the trial.

The BOFEK00 admission claim is further bounded to `SWKIMPL=0`. The broader
`SWKIMPL=1` dynamic-head Jacobian contains an existing implicit
surface-conductivity derivative surface that has not been independently
finite-difference-qualified by BOFEK00. This work unit does not silently
generalize its result to that mode.

## Frozen-timestep qualification

Preregistered fixture:

- 24 steps;
- each `dt=0.005 day`;
- total horizon `0.12 day`;
- rainfall `12 cm/day`;
- ponding maximum `0.05 cm`;
- runoff resistance `0.05 day`;
- `RSROEXP=1`;
- zero bottom/drainage flux;
- `SWKIMPL=0`.

Evidence:
`docs/verification/evidence/F-PE-BOFEK00_FROZEN_RESULT.json`.

Comparison:

| metric | canonical preimage | corrected |
| --- | ---: | ---: |
| nonlinear iterations | 117 | 98 |
| backtracks | 117 | 98 |
| cumulative runoff, cm | 0.4493205111812004 | 0.4493205111812251 |
| final top head, cm | 0.5263806508783677 | 0.5263806508786227 |
| final ponding, cm | 0.3655317988928389 | 0.3655317988928460 |
| max abs water ledger, cm | 3.33e-14 | 2.61e-14 |

Thus with exactly the same timestep sequence the physical trajectory agrees
to round-off while nonlinear work falls by 19 iterations/backtracks, about
16.2 percent. The cumulative-runoff delta is
`2.46e-14 cm`.

This is the correctness result. It is independent of timestep-policy choice.

## Adaptive-timestep interaction

The current canonical `TimeControl` decision statements are source-guarded
from:

- `src/legacy/b1_10_fci11_port/timecontrol_part04.inc`;
- `src/legacy/b1_10_fci11_port/timecontrol_part05.inc`.

A controlled qualification fixture uses the same policy constants on both
solvers:

- `dtmin=0.001 day`;
- `dtmax=0.02 day`;
- initial `dt=sqrt(dtmin*dtmax)`;
- `NUMBIT_CRIT=4`;
- `MaxIt=8`;
- growth factor `2.0`;
- accepted-step decrease factor `0.5`;
- nonconvergence reduction divisor `2.0`.

These are fixture inputs, not proposed BOFEK defaults.

Evidence:
`docs/verification/evidence/F-PE-BOFEK00_ADAPTIVE_RESULT.json`.

Results:

| metric | canonical preimage | corrected |
| --- | ---: | ---: |
| attempts | 14 | 8 |
| accepted steps | 14 | 8 |
| rejected attempts | 0 | 0 |
| growth events | 1 | 2 |
| reductions | 0 | 0 |
| nonlinear iterations | 71 | 38 |
| backtracks | 71 | 38 |
| cumulative runoff, cm | 0.4614801661367161 | 0.4843261930227983 |
| final top head, cm | 0.5909529810442085 | 0.7593732521537478 |
| max abs water ledger, cm | 4.52e-14 | 4.52e-14 |

The baseline accepted-dt sequence remains near `0.00894427 day` after its
first growth. The corrected solver crosses the unchanged growth criterion
again and subsequently accepts approximately `0.01788854 day`.

The adaptive runoff delta is `+0.02284603 cm`, approximately 4.95 percent
of the canonical-preimage value. Because the frozen-dt runoff delta is only
round-off scale, this adaptive difference is attributed to the unchanged
timestep policy reacting to changed solver iteration counts. It is not a
direct physical runoff change caused by the corrected Jacobian.

No rejected-step/reduction comparison is exposed by this fixture because
neither paired run rejected a step. That is a negative result, not evidence
that the controller cannot reduce a step.

Wall-clock timing of these micro-executables rounded to `0.0 s` on the
runner and is not scientifically useful. No runtime-speed claim is admitted
from that measurement. Deterministic solver-work counts are retained as
performance characterization only.

## Adjacent preservation

Latest BOFEK00 workflow:
GitHub Actions run `36405051634`, job `108871669579`.

All steps pass, including:

- corrected wet-regime O0/O2 gate;
- frozen canonical-preimage versus corrected comparison;
- adaptive TimeControl interaction comparison;
- existing TEMPORAL08 P0 O0/O2 runtime-chain preservation.

The preservation run reports
`FPE_TEMPORAL08_DEFAULT_OFF_REGISTRY=PASS` and
`FPE_TEMPORAL08_P0=PASS`.

## Classification

### BUG/CORRECTNESS

Confirmed on current canonical:

- incomplete dynamic top-boundary Jacobian on the qualified fixed-K wet head
  route;
- Newton-candidate/dt-dependent branch selection before analytical
  linear runoff.

### NUMERICAL_POLICY

Unchanged by the correction.

The adaptive experiment demonstrates that the existing policy can make
different accepted-dt decisions after a correctness repair because its input
iteration counts change. That interaction must not be interpreted as a new
policy recommendation.

### PERFORMANCE

Frozen solver work decreases from 117 to 98 nonlinear iterations.
Adaptive fixture work decreases from 71 to 38 iterations because the
unchanged controller subsequently selects larger timesteps.

No wall-clock admission claim is made.

### MODEL/PROCESS_CHOICE

No process formulation, runoff exponent, forcing interpretation, drainage
model or BOFEK soil choice is changed.

## Admission verdict and BOFEK consequence

Top-level defect classification:

`B. DEFECT_CONFIRMED_CURRENT_REFERENCE`.

Correction status:

`QUALIFIED_ADMISSION_CANDIDATE_FIXED_K_DYNAMIC_TOP_SWKIMPL0`.

F-PE-BOFEK01/02 timestep/convergence optimization must remain gated until
this correction is admitted into canonical. After admission it may start for
the same qualified fixed-K, `SWKIMPL=0` Reference surface.

Any BOFEK experiment that changes to or relies on `SWKIMPL=1` dynamic
head-boundary behavior remains gated pending a separate Jacobian
qualification for that implicit-conductivity surface.

Discretization work demonstrably independent of this top-boundary/timestep
surface is not blocked by BOFEK00.
