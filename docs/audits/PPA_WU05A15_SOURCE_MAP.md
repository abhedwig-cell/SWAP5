# PPA-WU05-A15 source map — exact B1.11 dFdhMp

Date: 2026-10-01

Status: `EXACT_SOURCE_MAP`

Source authority:

- nested `SWAP.ZIP` SHA-256
  `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`;
- `SWAP/macrorate.f90` SHA-256
  `537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`.

## Top-level derivative call surface

After MACRORATE has calculated and limited the exchange rates, exact B1.11 executes the
derivative section only when `ITask /= 1`.

The active derivative calls are:

1. `ABSORPTION(2,...)` for every macropore domain;
2. `SATFLOW(4,...)` for the **ordinary/main saturated matrix zone**.

The derivative section does **not** call `SATFLOW(4)` for the perched/interflow zone.

Therefore exact B1.11 contributes no explicit `dFdhMp` term for `QInIntSat`.

This absence is part of the source oracle and must not be filled in by inference.

## Unsaturated absorption derivative

For each active unsaturated compartment outside the perched interval, derivative work is
performed only when the final `QOutMtxUnsDmCp` exceeds `1e-7 cm/day`.

### Sorptivity-selected branch

The standard source configuration has `swabs=1`.

Exact formula:

`Deriv = -QOut * SorpAlfa / (ThtSrpRef - Theta)`

then:

`Deriv = Deriv * moiscap(h)`.

Thus:

`dQexc/dh = -QOut * alpha * C(h) / (theta_ref - theta)`.

The source uses the trial-local sorptivity reference after any event initialization.

### Darcy-selected branch

If the selected absorption branch is Darcy:

`Deriv = -QOut / DelH`

when `abs(DelH) > 1e-14`; otherwise zero.

`DelH` is the same macropore-minus-matrix head difference used by the rate calculation.

## Main saturated matrix derivative

Exact B1.11 calls:

`SATFLOW(4,id,NumNod,ICpTpSatZon,GwlFlCpZo,...)`.

For each relevant main-saturated compartment:

`dFdhMp(ic) -= (QOutMtxSatDmCp - QInMtxSatDmCp) / DelHDmCp`

when `abs(DelHDmCp) > 1e-14`.

With the A6 sign convention:

`qexc_to_matrix = QOut - QIn`

this is:

`dQexc/dh = -qexc_to_matrix / DelH`.

The derivative is accumulated over macropore domains onto the matrix-node diagonal.

## Perched derivative: exact negative evidence

Although `MACRORATE(1)` calls SATFLOW for perched/top saturated interflow and produces
`QInIntSatDmCp`, the derivative section contains no matching perched
`SATFLOW(4)` call.

A15 therefore returns **zero explicit derivative** for the perched `QInIntSat` term.

This does not mean perched exchange is head-independent physically. It means the exact
B1.11 Newton linearization does not include that derivative contribution.

## Covering-layer special derivative

SATFLOW(4) contains a separate derivative for the compartment immediately above
`IcTopMp` when a covering layer exists.

Covering-layer macropore physics is outside the current A8-A11 admitted/research envelope.

A15 records this source branch but does not implement or qualify it.

## HeadCalc sign

Exact HeadCalc uses:

`residual -= QExcMpMtx`

and:

`dfdh_main -= dFdhMp`.

The typed A15 result therefore reports `dQexc_to_matrix/dh` with the same sign as
`dFdhMp`.

## Scope

A15 implementation covers the current no-covering-layer A6/A11 route:

- standard `swabs=1` sorptivity derivative;
- Darcy unsaturated derivative;
- ordinary main-saturated derivative;
- explicit zero perched derivative.

No solver callback is wired by A15.
