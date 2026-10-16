# MC-NUT01 organic-N source reference correction

Status: **PROPOSED_CANONICAL_REFERENCE_CORRECTION** (donor decision requalified in this work unit)  
Date: 2026-10-07

## Scope

This record concerns exact B1.11 `SWAP/wofost_soil_orgmatn.f90` and the
`SW431-NUT-ORGANIC` dependency of the Soil-N migration.

## Source defect

The detailed FOM nitrogen balance accumulator `NFOM_min` subtracts nitrogen
incorporated into both destination pools:

`NFracFOM - AsfaFOM_Bio*NFracBio - AsfaFOM_Hum*NFracHum`.

The later scalar `Nminer`, which feeds mineral-N transport, instead subtracts
the biomass term twice:

`NFracFOM - AsfaFOM_Bio*NFracBio - AsfaFOM_Bio*NFracBio`.

The exact B1.11 authority contains both expressions; the public source family
corroborates the same discrepancy.

## Decisive balance evidence

B1.11 `Wofost_SoilBalanceCheck` defines organic-N output as:

`Out_orgN = NFOM_min + NBio_min + NHum_min`.

The same balance routine defines mineral-N input from organic turnover as:

`NH4_miner = Nminer * dz_WSN`.

Whole-system nitrogen conservation therefore requires the mineral-N receipt
from organic turnover to equal the organic-N loss booked by the authoritative
organic pool balances.

## Decision

SWAP5 treats the duplicated Bio term in the later `Nminer` FOM expression as
a source defect and uses the mass-consistent reference correction:

`Nminer = (NFOM_min + NBio_min + NHum_min) / dz_WSN`.

Equivalently, the production owner may book the interval amount directly as:

`NH4_miner = NFOM_min + NBio_min + NHum_min`.

This correction is preferred over re-evaluating a second scalar formula because
the FOM/Bio/Hum owner already determines the exact persistent organic-N loss.

## Required implementation contract

- FOM, Bio and Hum remain the single authoritative organic-matter stores.
- Organic N is derived from those stores and immutable N fractions.
- The organic-turnover candidate computes the new OM stores first.
- The mineral-N transfer is derived from the resulting loss of organic N.
- Positive organic-N loss becomes an equal NH4-N credit.
- Negative organic-N loss is immobilisation and becomes an equal NH4-N debit.
- The Soil-N owner applies OM deltas and mineral-N transfer atomically.
- Insufficient NH4 for immobilisation rejects the candidate without mutation.
- Restart persists the OM stores and mineral pools; `Nminer` itself is derived,
  not persistent state.

## Qualification requirement

Exact-source qualification must continue to retain the two conflicting B1.11
expressions as a defect witness, and additionally prove that the selected
reference correction closes:

`organic N change + mineral N change = 0`

for turnover-only intervals, before external additions, crop uptake,
denitrification or boundary transport are applied.

## Nonclaims

- This decision does not yet admit the full organic turnover operator.
- Existing WOFOST81 crop-N semantics remain unchanged.
- The SWBR aquifer source defect remains a separate unresolved decision.

## Next work

Port/qualify the FOM/Bio/Hum turnover candidate and derive its NH4
mineralisation/immobilisation transfer from the owner-level organic-N change.

Canonical qualification requires an exact one-line corrected-reference transform over archive orgmatn SHA25685146e95249b41ed9b5202b507cb1647784592a313e36e75010da9bbf9a733f6. The immutable B1.11 archive and global reference manifest are unchanged. The bounded corrected reference is identified as MC-NUT01-R1, not a global B1.12 release. Execute the original defect witness first, then qualify the corrected B1 source and B2 route independently against its whole-N balance.
