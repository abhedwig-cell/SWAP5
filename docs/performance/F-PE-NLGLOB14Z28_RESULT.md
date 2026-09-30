# F-PE-NLGLOB14Z28 result — variable-dimension timestep-manager bootstrap

Date: 2026-09-30

Status:

`QUALIFIED_Z28_VARIABLE_DIMENSION_MANAGER_BOOTSTRAP`

Qualification authority:

- successful workflow run: `36730098775`;
- successful job: `109937108754`;
- prior run `36729999104` failed only on a Fortran source-line-length issue before result exposure;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Research postimage before result persistence:

`research/f-pe-nlglob14z28-variable-dimension-manager@a9797b11bc2eb558977a68d7151fa3e25b05e6a0`

## Aggregate result

Frozen classification:

`VARIABLE_DIMENSION_PRIMITIVES_QUALIFIED`.

Frozen aggregate:

`QUALIFIED_Z28_VARIABLE_DIMENSION_MANAGER_BOOTSTRAP`.

## Executed reshape sequence

The production reference workspace and production TRIDAG path successfully execute:

`12 -> 11 -> 12 -> 13 -> 12`

with exact requested active dimension after each reshape.

No fixed-16 fallback is observed.

## Algebra qualification

All requested dimensions solve the deterministic tridiagonal system to roundoff.

### n = 11

- workspace active_nodes: 11;
- workspace payload: 2184 bytes;
- structural TRIDAG work: 21 row operations;
- normalized structural work versus n=16: about 0.6774;
- max solution error: about 2.22e-16;
- max residual: about 5.55e-16.

### n = 12

- workspace active_nodes: 12;
- workspace payload: 2380 bytes;
- structural work: 23;
- normalized work: about 0.7419;
- max solution error: about 1.11e-16;
- max residual: about 3.33e-16.

### n = 13

- workspace active_nodes: 13;
- workspace payload: 2576 bytes;
- structural work: 25;
- normalized work: about 0.8065;
- max solution error: about 2.22e-16;
- max residual: about 5.55e-16.

### n = 16 control

- workspace active_nodes: 16;
- workspace payload: 3164 bytes;
- structural work: 31;
- normalized work: 1.0;
- solution error and residual at machine-zero for the frozen fixture.

## Architectural interpretation

The production reference-solver infrastructure already supports the core software property required by an adaptive timestep manager:

**the nonlinear/linear workspace and TRIDAG solve dimension can genuinely follow active_nodes.**

This removes the fixed-dimension limitation identified by Z27.

The qualified primitive also shows monotone reductions in:

- workspace payload;
- exact TRIDAG row work.

The result does not yet claim a full Richards runtime speedup because the complete moving-interface physical residual and lower saturated-tail reconstruction are not yet bound to the reduced solve.

## Qualified claim boundary

Qualified:

- variable active-node workspace reshaping;
- variable-dimension production TRIDAG execution;
- exact algebraic solutions for n=11,12,13,16;
- no observed stale-state leakage across the frozen reshape sequence;
- structural algebra work decreases as active dimension shrinks.

Not qualified:

- full moving-interface physical equivalence;
- lower saturated-tail reconstruction in the production-shaped path;
- end-to-end SWAP runtime speedup;
- production timestep-manager admission.

## Consequence

The next workunit should bind the already-qualified moving-interface physical semantics to this variable-dimension solve seam.

That successor must compare:

1. full-column reference;
2. adaptive variable-dimension manager;

on identical accepted trajectories, with hard gates on:

- accepted h/theta state;
- physical mass;
- interface ownership;
- rollback/transaction semantics;
- provider route;
- nonlinear work;
- runtime.

Only that A/B result can establish the practical speed value of the manager.

## Production boundary

Research/bootstrap only.

No production default change.

`LEGACY_NUMERICS` remains production default.
