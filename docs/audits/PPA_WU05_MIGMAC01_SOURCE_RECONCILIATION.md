# PPA-WU05-MIGMAC01 source reconciliation — covering-layer macropore input

Date: 2026-10-01

Status: `SOURCE_SEMANTICS_RECONCILED_OPERATOR_IMPLEMENTED_NOT_YET_RUNTIME_ADMITTED`

Branch authority:
`research/ppa-wu05-migmac01-covering-layer`

## Recovered B1.11 semantics

The retained exact-4.3.1 source artefacts and the upstream SWAP source carrying the same
legacy MACRORATE equation block establish the covering-layer branch.

MACROGEOM sets `IcTopMp > 1` when the configured macropore top lies below the soil surface.
The matrix compartment immediately above the first macropore compartment is:

`ic = IcTopMp - 1`.

For a surface-connected macropore system (`IcTopMp == 1`), direct top input is rain,
irrigation and melt plus the separately owned lateral overland receipt.

For a covered system this direct surface route is disabled. Instead B1.11 computes a
matrix-to-covered-macropore vertical source only when:

`h(IcTopMp-1) > 0`.

With `Henpr1 = 0`, `Ld = dipomi` and legacy `pi = 3.14159`:

`r0 = 0.5*Ld*(1-sqrt(1-VlMpStCp(IcTopMp)-VlMpDyCp(IcTopMp)))`

`w_geom = 1 / (1 + Ld/(pi*dz(ic)/2)*log(Ld/(pi*r0)) + Ld^2/(6*dz(ic)^2))`

`FlwInTop = w_geom*KsatCovLay*((h(ic)-Henpr1)/(dz(ic)/2)+1)*dt`.

The total is partitioned over macropore domains by:

`ArMpTpDm(id)/ArMpTp`.

After limiting, B1.11 explicitly books the accepted covered-top source at matrix node
`IcTopMp-1` as:

`QInMtxSatDmCp(id,IcTopMp-1) = QInTopVrtDm(id)`

and therefore:

`QExcMtxDmCp(id,IcTopMp-1) = -QInTopVrtDm(id)`.

This is an **internal matrix-to-macropore transfer**, not external rainfall mass and not a
returned-surface receipt.

## Consequences for SWAP5 ownership

1. A9 must remain unchanged for `top_node == 1`.
2. Covered input must not consume A9 rain/irrigation/melt/lateral forcing.
3. The source must be evaluated from the trial matrix head at `top_node-1`, because the
   B1.11 source depends on that head.
4. The accepted transfer must appear equal-and-opposite in the matrix source/sink ledger and
   macropore storage ledger.
5. The current SWAP5 geometry result already carries static + dynamic top macropore volume
   and per-domain top volume, so no new mutable geometry state is required merely to evaluate
   this operator.
6. MIGMAC01 does not decide how dynamic crack volume itself is generated. That remains M2.
   It consumes the already-owned geometry result exactly as other standard macropore processes do.

## Implemented process primitive

`src/process/macropore/mod_macropore_covering_layer_input.f90`

implements only the recovered B1.11 covering-layer potential-input operator.

It deliberately has no surface forcing fields and no committed-state mutation.

Focused oracle:

- top node = 3;
- dt = 0.1 d;
- h(top-1) = 3 cm;
- dz(top-1) = 2 cm;
- dipomi = 10 cm;
- KsatCovLay = 5 cm/d;
- total top macropore volume = 0.2 cm;
- domain volumes = [0.12, 0.08] cm.

Expected exact legacy-form result:

- total = 0.18372261330635548 cm;
- domain 1 = 0.11023356798381329 cm;
- domain 2 = 0.07348904532254219 cm.

The gate also requires zero input at nonpositive covering-layer head and fail-closed invalid
geometry.

## Remaining before runtime admission

The operator is not yet a production admission claim.

MIGMAC01 still needs a transaction-level composition in which the source is reevaluated from
each Richards candidate head and booked exactly once as internal matrix-to-macropore exchange.
That composition must prove reject/replay/restart and preserve A9/A10/PERCH21.

No direct rain shortcut for `IcTopMp > 1` is permitted.
