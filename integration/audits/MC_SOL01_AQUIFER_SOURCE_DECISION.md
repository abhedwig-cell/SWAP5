# MC-SOL01 aquifer source disposition

Status: **UNSUPPORTED_SOURCE_DEFECT**

Capability: `SW431-SALT-AQUIFER` (`SWBR=1`)

Date: 2026-10-07

## Exact B1.11 defect

The exact B1.11 `solute.f90` authority enters the SWBR aquifer block after the
matrix-node loop. At that point the loop index is `numnod+1`, while
`bdenskfsatporos` is dimensioned over matrix nodes. The literal
`bdenskfsatporos(i)` access is therefore out of bounds.

The persisted O0/O2 bounds witness reproduces this for positive and negative
signed drainage cases. This is a source defect, not an implementation choice.

## Why `bdenskfsatporos(numnod)` is not an admissible silent repair

The source constructs the coefficient as:

`bdens(layer(i))*kfsat + poros`.

Source declarations and reader authority identify:

- `KFSAT`: linear adsorption coefficient in the aquifer, units L3/M;
- `POROS`: aquifer porosity;
- `DAQUIF`: saturated-aquifer thickness;
- `DECSAT`: aquifer decomposition rate;
- `CDRAINI`: initial aquifer/drainage concentration.

A linear adsorption coefficient with units L3/M requires a solid bulk-density
term before it can be added to porosity as a storage/retardation coefficient.
However, the SWBR input contract contains **no aquifer bulk-density parameter**.
The only `BDENS` values belong to soil layers.

No source declaration, reader rule, parameter description, or discovered
reference states that the bottom soil-layer bulk density is the aquifer bulk
density. Replacing the invalid index by `numnod` would therefore introduce a
new physical assumption while claiming B1.11 preservation.

## Disposition

`SW431-SALT-AQUIFER` is classified **UNSUPPORTED_SOURCE_DEFECT** for the
SWAP 4.3.1/B1.11 functional-coverage census.

This is a definitive disposition, not an open implementation gap.

SWAP5 therefore:

1. persists an aquifer-mass slot only as inert companion/restart state where
   needed by the shared reactive layout;
2. rejects every non-zero aquifer process mutation in the B1.11 reactive
   transaction;
3. does not infer an aquifer bulk density from the bottom soil layer;
4. does not claim SWBR breakthrough/decay production equivalence.

## What would be required to re-open this capability

A future, explicitly new model may re-open aquifer breakthrough only with a
separate architecture decision that introduces or otherwise justifies:

- aquifer bulk density / storage coefficient;
- aquifer water volume `DAQUIF*POROS`;
- adsorption storage `rho_b*KFSAT`;
- signed recharge/discharge convention;
- decay and breakthrough ordering;
- whole-aquifer mass balance;
- retry/reject/restart qualification.

Such a model would be a qualified replacement, not a literal B1.11 port.

## Census consequence

The capability should move from `ACTIVE_MIGRATION` to a definitive
unsupported/source-defect disposition once the master coverage ledger is
reconciled. It must not remain counted as remaining implementation work.
