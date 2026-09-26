# F-PE-APPROX02_CLOSEOUT — practical Richards solve-effort frontier

Date: 2026-09-26

Status: `CLOSED_WITH_QUALIFIED_OPT_IN`

PR:
`#630 — F-PE-APPROX02: practical Richards solve-effort frontier`

Branch:
`work/f-pe-approx02-richards-effort`

Stacked parent:
`F-PE-APPROX01@f3f28542859c0fceb2fc2b80dafd47b1a39049e3`

## Purpose

APPROX02 measured the runtime/error frontier of reducing local Richards convergence effort while keeping exact/default behavior as authority.

The first production lever tested was joint relaxation of:

- head absolute tolerance;
- head relative tolerance;
- compartment balance tolerance;
- total balance tolerance.

Timestep policy, retry policy, iteration limits, backtracking limits, transaction mass accounting and constitutive physics were held fixed.

## Candidate history

### A2 — `1e-4`

Direct/local performance was very strong:

- median single-step solver speedup about 56%;
- multistep speedup about 50%;
- state and flux errors remained small in the tested local matrix.

But replicated live SWAP + MODFLOW6 qualification failed in two of three jobs with a new SWAP trial failure.

Decision:

`REJECTED_COUPLED_ROBUSTNESS`

### A2B — `1e-6`

A2B was more conservative and still materially faster:

- multistep median speedup about 37.5%;
- application-shaped speedup about 24%;
- hydrological deviations remained extremely small.

However, one of three live MODFLOW6 replicas produced the same new SWAP trial-failure class.

Decision:

`REJECTED_COUPLED_ROBUSTNESS`

### A2C — `1e-8`

A2C moved two orders of magnitude back toward the exact reference.

It was the first envelope to retain material runtime benefit while passing the replicated coupled robustness gate.

## A2C multistep matrix

Across:

- B01;
- B12;
- O05;
- O14;
- wet / mid / dry;
- 20-step transient trajectories;

all 12 cases converged.

Current-head matrix summary:

- median speedup approximately `28.46%`;
- worst relative pressure-head deviation approximately `3.54e-10`;
- worst final-head relative deviation approximately `2.36e-10`;
- worst relative water-content deviation approximately `2.99e-11`;
- worst relative bottom-flux deviation approximately `1.79e-10`;
- worst cumulative bottom-exchange relative deviation approximately `5.70e-11`.

Hard wet cases still showed substantial nonlinear-work reduction, for example:

- B01-wet: 250 -> 174 nonlinear iterations;
- O05-wet: 236 -> 165;
- O14-wet: 180 -> 126.

## Canonical application sequence

The 20-step production application sequence passed on the production A2C postimage.

Observed:

- speedup approximately `15.5%`;
- accepted substeps identical;
- zero retries in both exact and A2C arms;
- zero canonical mass residual in both arms;
- zero cumulative net-flow difference;
- zero cumulative storage difference;
- zero maximum step-net difference.

The application fixture did not reduce its reported nonlinear count, so its speedup must not be interpreted as a simple iteration-count ratio.

## Live SWAP + MODFLOW6 qualification

Three independent coupled jobs passed on the final production A2C postimage.

Every replica preserved exactly:

- final MODFLOW head;
- final SWAP groundwater exchange flux;
- cumulative accepted interface ledger exchange;
- coupled iteration count;
- absence of new SWAP trial failures.

Measured coupled-loop speedups:

- approximately `18.86%`;
- approximately `17.32%`;
- approximately `7.83%`.

Median:

approximately `17.32%`.

Mean:

approximately `14.67%`.

The coupling loop is short, so the spread is treated as timing variance. The robust statement is that all three replicas were speed-positive and endpoint-identical.

## Production opt-in binding

A2C is bound to an explicit production parameter flag:

`practical_richards_a2c_active`

Default:

`false`

When active, the serialized Reference backend sets exactly:

- head absolute tolerance = `1e-8`;
- head relative tolerance = `1e-8`;
- compartment balance tolerance = `1e-8`;
- total balance tolerance = `1e-8`.

It does not change:

- ponding tolerance;
- transaction mass tolerance;
- temporal policy;
- retry policy;
- max iterations;
- backtracking policy;
- constitutive physics.

The production observation explicitly exposes:

- whether A2C is active;
- the four effective tolerances.

The production-binding gate confirms the qualified quartet exactly.

## Default exact preservation

A2C is default OFF.

The current exact FGC44 production route passes unchanged when the flag is false.

No exact/default production numerical value is altered by the presence of the A2C opt-in.

## Interpretation

APPROX02 found an important practical boundary.

The looser `1e-4` and `1e-6` settings looked scientifically benign in direct and multistep state-error metrics but still created coupled robustness failures.

That is strong evidence that production practical-mode selection cannot be made from local hydrological error magnitude alone.

The coupled participant/corrector lifecycle is an independent admission dimension.

A2C at `1e-8` is the first tested convergence envelope that passes both.

## Admission status

A2C is qualified as a production-shaped practical-performance opt-in.

This does not make it canonical until the stacked parent chain is admitted.

The exact default remains authority.

## APPROX02 decision

APPROX02 has met its closure condition:

- the convergence-effort frontier was measured;
- two overly aggressive candidates were rejected on coupled robustness;
- a stricter envelope was independently qualified;
- that envelope is bound to an explicit default-OFF production flag;
- provenance is exposed;
- exact/default behavior remains intact.

No further tolerance ratcheting is added to APPROX02.

## Next workunit

Preregistered:

`F-PE-APPROX03 — practical timestep / temporal-effort frontier`

Preregistration:

`docs/performance/F-PE-APPROX03_PREREGISTRATION.md`

APPROX03 will test whether temporal refinement / accepted-substep effort remains a material source of runtime after A1 + A2C.

## Closure statement

F-PE-APPROX02 is closed with A2C retained as the second qualified production-shaped practical performance mode.

Planning interpretation:

- hard-case multistep solver gain: often 20-40%;
- production application-sequence gain: about 15%;
- replicated coupled-loop gain: all runs positive, median about 17%, with an observed 8-19% band;
- qualified hydrological trajectory errors extremely small on the tested 4x3 matrix;
- coupled endpoint exact in all three qualified replicas;
- exact default route preserved.

The performance program should now proceed to F-PE-APPROX03.
