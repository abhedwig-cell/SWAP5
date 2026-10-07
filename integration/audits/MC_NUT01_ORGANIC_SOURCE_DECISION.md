# MC-NUT01 organic-N source decision boundary

Status: SOURCE_DEFECT_DECISION_REQUIRED  
Date: 2026-10-07

## Scope

This record concerns B1.11 `SWAP/wofost_soil_orgmatn.f90` and the
`SW431-NUT-ORGANIC` dependency of the Soil-N migration.

## Finding

The organic-matter routine contains two formulas that purport to book the
nitrogen released from FOM transformation.

The detailed balance accumulator `NFOM_min` subtracts nitrogen incorporated
into both the biomass and humus destinations:

`NFracFOM - AsfaFOM_Bio*NFracBio - AsfaFOM_Hum*NFracHum`.

Later, the scalar `Nminer` that feeds the mineral-N transport instead
subtracts the biomass term twice:

`NFracFOM - AsfaFOM_Bio*NFracBio - AsfaFOM_Bio*NFracBio`.

These expressions are not generally equivalent. The public SWAP source family
contains the same discrepancy. The exact B1.11 authority is fail-closed checked
by `tools/audits/probe_b111_nut_sol_exact_source.py`, including the exact
member SHA-256.

## Consequence

SWAP5 must not silently choose one formula while claiming literal B1.11
preservation.

The Soil-N owner, amendment/residue split, mineral-N transport and reaction
interfaces can be implemented independently. Production admission of organic
turnover/mineralisation requires an explicit reference decision choosing one
of:

1. literal preservation of the later `Nminer` expression;
2. a qualified reference correction using the internally balanced
   `NFOM_min` expression;
3. another explicitly derived mass-conservative replacement with its own
   source/reference qualification.

Whichever route is selected must preserve one authoritative FOM/Bio/Hum
state, produce one mineral-N transfer receipt, and close total nitrogen mass.

## Nonclaims

- This record does not classify the intended scientific formulation by itself.
- No organic-turnover production route is admitted here.
- Existing WOFOST81 crop-N admission is unchanged.
- The separately identified SWBR aquifer bounds defect is unrelated.

## Next safe work

Continue the independent mineral-N transport/reaction and SOL01 owner slices.
Do not bind `SW431-NUT-ORGANIC` into production until the reference decision
is explicit and qualified.
