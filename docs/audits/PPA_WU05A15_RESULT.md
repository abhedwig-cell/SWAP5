# PPA-WU05-A15 result — source-faithful macropore exchange derivative

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_SOURCE_FAITHFUL_EXCHANGE_DERIVATIVE`

Baseline:
`research/ppa-wu05-a14-inner-richards-macropore-design@ad18a3f3551a13f49abd221c6ea53158c043dab9`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

Qualified postimage:
`0b678c48c7bf6d44be45b24ad4985f2c9b04b3db`.

Qualification run: `36840728248` — SUCCESS.

## Exact source scope

A15 recovers the active B1.11 `dFdhMp` surface used by
`headcalc -> jacobian_F -> MACROPORE(3) -> MACRORATE(2)`.

Qualified derivative branches:

1. unsaturated sorptivity-selected absorption;
2. unsaturated Darcy-selected absorption;
3. ordinary/main saturated matrix-to-macropore and macropore-to-matrix exchange.

Exact negative source evidence:

- perched `QInIntSat` is calculated in `MACRORATE(1)`;
- the B1.11 derivative section contains no matching perched `SATFLOW(4)` call;
- therefore the explicit B1.11 derivative contribution of perched `QInIntSat` is zero.

The separate covering-layer derivative branch is documented but remains outside the
current A8-A11 envelope and is not implemented by A15.

## Typed evaluator

A15 adds:

`mod_ppa_wu05a15_exchange_derivative`

with a side-effect-free evaluator over an already evaluated A6 rate bundle.

Outputs:

- unsaturated local `dQexc/dh`;
- main-saturated local `dQexc/dh`;
- domain-summed node derivative;
- explicit `perched_derivative_included = false`.

The evaluator reads current capacity `C(h)` but does not modify macropore continuation,
history, geometry, matrix state or restart state.

## Qualified formulas

### Sorptivity-selected unsaturated exchange

For the standard B1.11 `swabs=1` route:

`dQexc/dh = -QOut * SorpAlfa * C(h) / (ThtSrpRef - Theta)`.

The typed implementation uses the final A6-limited `QOut` and the A6 trial-local
sorptivity reference.

### Darcy-selected unsaturated exchange

For nonzero source head difference:

`dQexc/dh = -QOut / DelH`.

### Main saturated exchange

With:

`qexc_to_matrix = QOutMtxSat - QInMtxSat`

the exact SATFLOW derivative is:

`dQexc/dh = -qexc_to_matrix / DelH`.

### Perched interflow

Explicit derivative:

`0`

because no perched `SATFLOW(4)` call exists in the exact derivative section.

## Qualification evidence

The focused A15 gate passes at both `-O0` and `-O2`, with identical output.

Markers:

- `PPA_WU05A15_PERCHED_NEGATIVE_DERIVATIVE=PASS`;
- `PPA_WU05A15_MAIN_SAT_DERIVATIVE=PASS`;
- `PPA_WU05A15_SORPTIVITY_DERIVATIVE=PASS`;
- `PPA_WU05A15_DARCY_DERIVATIVE=PASS`;
- `PPA_WU05A15_EXCHANGE_DERIVATIVE_GATE=PASS`;
- `PPA_WU05A15_O0_O2_IDENTITY=PASS`.

Run `36840728248` also passed:

- corrected A11 carrier preservation;
- the complete A7-A10 admitted macropore preservation gate.

## Decision

`QUALIFIED_SOURCE_FAITHFUL_EXCHANGE_DERIVATIVE`

A15 is a qualified process prerequisite for the A14 inner-Richards callback architecture.

It is not a solver integration and is not canonically admitted.

## Next safe step

Open A16 as a research callback prototype that:

1. extends the currently unused `macropore_exchange_provider_t` contract with current
   water content and local derivative;
2. wires it only into the explicit Reference-Richards `vector_F/jacobian_F` path;
3. keeps provider absence exactly equivalent to the current path;
4. uses accepted macropore state as read-only context;
5. proves current-iterate perched exchange and transaction isolation before any production
   admission is considered.

The frozen Status-A denominator remains unchanged.
