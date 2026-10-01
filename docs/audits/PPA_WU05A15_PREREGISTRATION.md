# PPA-WU05-A15 preregistration — source-faithful macropore exchange derivative

Date: 2026-10-01

Status: `PREREGISTERED / DERIVATIVE_MIGRATION`

Baseline:
`research/ppa-wu05-a14-inner-richards-macropore-design@ad18a3f3551a13f49abd221c6ea53158c043dab9`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

## Purpose

Recover, implement and qualify the exact B1.11 local macropore exchange derivative
`dFdhMp` as a typed, side-effect-free process result.

A15 does not wire that derivative into HeadCalc. It provides the prerequisite derivative
authority for the A14 callback design.

## Exact source scope

A15 is restricted to the derivative surface actually used by B1.11
`MACRORATE(2)`:

- unsaturated matrix/macropore absorption derivative;
- saturated **main-groundwater-zone** exchange derivative;
- covering-layer derivative only if source mapping proves it is in the currently supported
  A8-A11 envelope.

A15 must explicitly record whether perched `QInIntSat` contributes to `dFdhMp` in the
exact source. It must not invent a derivative absent from B1.11.

## Gates

### G1 — exact source map

Map every active `dFdhMp` contribution from exact `macrorate.f90`:

- branch condition;
- sign;
- source rate used;
- denominator/head dependence;
- compartments affected.

### G2 — typed derivative evaluator

Implement a side-effect-free evaluator returning local diagonal
`d(exchange_flux)/dh` in the same sign convention as A6 `qexc_to_matrix_rate`.

No persistent macropore state may be modified.

### G3 — source-oracle tests

For each admitted derivative branch, construct analytical fixtures and verify the typed
result against the exact B1.11 formula.

Include explicit negative evidence for source branches that do **not** contribute a
derivative.

### G4 — rate consistency

Verify that derivative signs are consistent with the corresponding A6 exchange rates and
the HeadCalc composition:

`residual -= qexc_to_matrix_rate`

`jacobian_diagonal -= dqexc_dhead`.

### G5 — preservation

A11 corrected carrier gate and A10 admitted preservation remain green if the A15 changes
touch shared A6 types/modules.

## Non-scope

- no HeadCalc callback wiring;
- no solver ABI change;
- no numerical convergence claim;
- no canonical admission;
- no dynamic crack derivative;
- no RossFast/parallel work.

## Decision states

- `QUALIFIED_SOURCE_FAITHFUL_EXCHANGE_DERIVATIVE`;
- `PARTIAL_DERIVATIVE_SCOPE_REQUIRES_ADDITIONAL_SOURCE_AUTHORITY`;
- or `FALSIFIED_TYPED_DERIVATIVE_ROUTE`.
