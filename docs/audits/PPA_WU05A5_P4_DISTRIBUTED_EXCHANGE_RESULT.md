# PPA-WU05-A5 P4 local distributed exchange result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / DISTRIBUTED_INTERNAL_EXCHANGE_CONSERVATIVE`

## Exact B1.11 source contract

For every active macropore domain and compartment, B1.11 defines:

`QExcMtxDmCp = QOutMtxSatDmCp + QOutMtxUnsDmCp - (QInIntSatDmCp + QInMtxSatDmCp)`.

The aggregate matrix/macropore exchange at a matrix node is:

`QExcMpMtx(ic) = sum_id QExcMtxDmCp(id,ic)`.

The column diagnostic is:

`QMaPo = sum_ic QExcMpMtx(ic)`.

In `MACROSTATE`, positive `QExcMtxDmCp` is subtracted from macropore storage.

Therefore the source-bound sign convention is:

- positive `QExc`: macropore -> matrix;
- negative `QExc`: matrix -> macropore.

## Local multi-domain test

Three domains over five compartments were given deterministic gross saturated/unsaturated in/out exchange terms.

Two geometry states were evaluated.

### Geometry A

Active bottoms:

`[4,3,2]`.

Integrated over `dt=0.1 d`:

- macropore exchange storage change: `-0.0180 cm`;
- matrix exchange storage change: `+0.0180 cm`;
- combined internal-exchange residual: machine zero.

### Geometry B — main domain becomes shallower

Active bottoms:

`[3,3,2]`.

The deepest main-domain exchange term becomes inactive.

Integrated result:

- macropore change: `-0.0175 cm`;
- matrix change: `+0.0175 cm`;
- combined residual: machine zero.

Every exchange value below the active bottom of each domain is zero.

## Interpretation

Distributed exchange ownership composes cleanly with moving domain geometry.

The coupling vector presented to Richards can be constructed as the node-wise sum over active macropore domains while the macropore candidate applies the equal/opposite domain-resolved amount.

No extra external flux or continuation state is required.

## Covering-layer note

B1.11 has one additional bookkeeping case for `IcTopMp > 1`:

the vertical covering-layer inflow is inserted as a negative `QExcMtxDmCp` in the compartment immediately above the macropore top.

That is still an internal matrix/macropore transfer and belongs in the same cancellation contract. It should be added explicitly when the A5 typed distributed evaluator gains covering-layer support.

## H5 disposition

`DISTRIBUTED_MATRIX_MACROPORE_EXCHANGE_CANCELS_INTERNALLY_WITH_MOVING_DOMAIN_BOTTOMS`.

Supported locally.

## State-surface result

No new continuation field is required by P4.

The next source-composition risk is not state ownership but full drainage topology and top/covering-layer interactions.

## Next step

Proceed to P5 source-bound multi-domain drainage topology, then compose P1-P5 into one typed multi-domain process candidate before restart/replay.
