# PPA-WU05-A18 source authority — Andelst perched Reference fixture

Date: 2026-10-01

Status: `QUALIFIED_SOURCE_BACKED_RUNTIME_AUTHORITY`

## Exact distribution

Authority is the user-supplied SWAP 4.3.1 distribution.

Pinned nested source archive:

`SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP`

SHA-256:

`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

Exact B1.11 `macrorate.f90` SHA-256:

`537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`.

## Local exact-source runtime recovery

The exact 4.3.1 source was rebuilt locally with gfortran.

The bundled TTUTIL static library was linked against Intel Fortran runtime symbols and
could not be used directly in the available Linux runtime. TTUTIL was therefore rebuilt
from the bundled TTUTIL source using gfortran.

This is a compiler/runtime portability action only. No SWAP physical equation was changed.

The rebuilt executable successfully ran the shipped official:

`cases/3.macroporeflow`

Andelst case to normal completion.

## Shipped Andelst perched census

Read-only CALCGWL diagnostics were added locally to the exact source.

The unmodified shipped Andelst macropore case did not contain a distinct perched body.

Observed `NPeGwl` detections coincided with the ordinary groundwater carrier:

- `NPeGwl = NodGwl = BPeGwl = 57`;
- `PeGwl - Gwl = 0`.

Therefore the shipped case is valid macropore runtime authority but not a positive
schijngrondwater/perched authority by itself.

## Source-native perched preconditioning

Rather than prescribing an artificial discontinuous pressure-head lens, the official
Andelst soil/hydraulic profile was started from its normal hydraulic state with macropore
exchange disabled and supplied with a surface-irrigation pulse using the same irrigation
magnitude/rate convention present in the supplied 4.3.1 example material.

Reference Richards then generated the perched body dynamically.

No soil hydraulic parameters, discretization, Richards numerical policy or perched
detection formula were changed.

The exact source runtime formed a distinct perched body and retained it over multiple
accepted time intervals, approximately from 05:30 through 11:53 on 1998-01-01.

## Accepted source snapshot

A read-only accepted-state logger was placed after `SoilWater(3)` and before
`TimeControl(3)`.

The selected accepted snapshot is:

- simulation time: `0.2493333334 d` after 1998-01-01 00:00;
- clock time: approximately 05:59:02;
- accepted step duration: `0.002 d`;
- ordinary groundwater level: `-79.56711114090561 cm`;
- perched level: `+0.630316146964261 cm`;
- perched bottom level: `-28.777845917377004 cm`;
- `NPeGwl = 1`;
- `BPeGwl = 29`;
- `NodGwl = 56`;
- accepted top flux: `-0.9746117284923626 cm/d`;
- accepted bottom flux: `-0.009930268623846343 cm/d`.

The complete 112-node pressure-head vector is persisted in
`tests/fpm/test_ppa_wu05a18_andelst_perched_reference.f90`.

The SWAP5 fixture reconstructs the exact Andelst 112-node grid and the eight Mualem-van
Genuchten layers from the supplied `swap.swp`.

## Independent SWAP5 baseline

Qualification run `36859002384` on postimage
`63492ddc342170cc4116675606073178ce5dae2a` proved the snapshot is independently
solver-stable with macropore callback disabled.

Evidence:

- Reference-Richards status = converged;
- nonlinear iterations = 3;
- internal retries = 0;
- mass residual = `-1.8453587095901280e-10 cm`;
- perched active = true;
- perched top node = 1;
- perched bottom node = 29;
- perched level = `0.63031614696426097 cm`;
- perched bottom = `-28.819658959530571 cm`;
- ordinary groundwater top node = 56;
- O0/O2 identity = pass.

This closes the A17 blocker
`NO_SOLVER_STABLE_REFERENCE_RICHARDS_PERCHED_AUTHORITY_FIXTURE`.

## Exact legacy macropore convergence reduction

Exact B1.11/4.3.1 source uses:

`FrReduQ = 0.1 ** IDecMpRat`

with `IDecMpRat = 0..3`.

Thus the source-defined exchange levels are:

- 1.0;
- 0.1;
- 0.01;
- 0.001.

HeadCalc escalates this reduction only after ordinary timestep-reduction handling can no
longer recover convergence.

A18 tested exactly this source ladder on the qualified perched state.

At factor 1.0:

- initial inner exchange = `-12.839647212405492 cm/d`;
- Reference Richards requests retry.

At the next exact legacy level, factor 0.1:

- initial inner exchange = `-1.2839647212405492 cm/d`;
- final exchange = `-0.25748894374328285 cm/d`;
- solve converges;
- macropore storage increases by
  `5.149778874865657e-4 cm`;
- internal exchange residual = 0;
- macropore balance residual = 0.

Qualification run `36860834649` passed at O0 and O2.

## Authority boundary

A18 qualifies:

- the solver-stable perched hydraulic fixture;
- active A11 perched detection on a source-backed state;
- active A16 inner-Richards provider;
- source-ladder recovery at `FrReduQ=0.1`;
- exact internal mass cancellation for the accepted inner result.

A18 does not yet qualify production automation of the `FrReduQ` retry ladder.

That retry-state machine is the next required workunit.
