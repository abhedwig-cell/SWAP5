# F-PE-TIMEINT12 closeout — dynamic-top higher-order integration

Date: 2026-09-29

Final status:

`BLOCKED_IMPLICIT_DYNAMIC_TOP_OPERATOR_ROBUSTNESS`

## Evidence chain

1. TIMEINT04-05:
   fully implicit variable-step BDF2 is a credible second-order mechanism on smooth fixed-flux trajectories with accepted adjacent step ratio 0.5..2.0.

2. TIMEINT12 prerequisite:
   the missing fully implicit dynamic-top surface-head derivative was derived and qualified against finite differences across 608 smooth same-route head-regime points.

3. TIMEINT12A:
   fully implicit BE on dynamic-top completes only 6/12 MOIST/WET/POND cases and fails the preregistered work-cost gates.

## Decision

Do not introduce BDF2 history on dynamic-top yet.

A multistep integrator should not be wrapped around a first-order fully implicit operator that is not robust on the target boundary composition.

This is not a reason to return to legacy DTMIN/DTMAX tuning.

It is a solver/operator-composition blocker.

## What remains qualified

- TIMEARCH redesign;
- variable-step BDF2 on smooth fixed-flux;
- BDF2 step-ratio envelope 0.5..2.0;
- representation-aware BDF2 balance floor;
- fully implicit dynamic-top analytical surface derivative.

## What is not qualified

- SWKIMPL=1 dynamic-top production execution;
- dynamic-top BDF2;
- adaptive BDF2 on wet/ponding SWAP trajectories;
- user-facing removal of DTMIN/DTMAX based on this line alone.

## Recommended successor

Open a separate operator/solver robustness study:

`F-PE-KIMPL-DYNTOP01 — fully implicit dynamic-top nonlinear-path attribution`.

Its question is narrower:

Why does SWKIMPL=1 lose robustness on dynamic-top when the same operator is robust on fixed-flux?

The first phase should trace the earliest failing KIMPL step in representative B01/O14 wet cases and compare it with:

- the corresponding KLAG step;
- the previous successful KIMPL step;
- boundary route and derivative;
- conductivity/dKdh;
- Newton residual/update;
- line-search/backtracking;
- local/total balance residuals.

No timestep controller should be tuned until that operator-composition issue is understood.

## Production boundary

LEGACY_NUMERICS remains production default.

No `src/**` change from TIMEINT12A.

