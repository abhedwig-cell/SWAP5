# SWAP-004 finding — tillage lookup arrays indexed by type code

## Classification

Legacy indexing/input-consistency defect. Audit status before this work: `CONFIRMED_UNFIXED`, high certainty, high severity.

## Defect

`Read_Tillage` reads event-level `TYPE_TILLAGE`, derives `tmax=maxval(TYPE_TILLAGE)`, then reads `ITYPE_TILLAGE` constrained to the accepted type-code range. However the lookup arrays are allocated as:

```fortran
allocate(iTT1(Ntill))
allocate(iTT2(Ntill))
```

and filled only for `j=1:Ntill`.

`Change_Tillage_Info` later executes:

```fortran
itype = Type_Tillage(iTill)
nlay  = iTT2(itype) - iTT1(itype) + 1
```

Thus the lookup-array index is a type code, not an event number. `TYPE_TILLAGE > Ntill` is accepted by the input path but can index outside `iTT1/iTT2`.

A strict reproducer with `Ntill=1`, `TYPE_TILLAGE=[3]`, `ITYPE_TILLAGE=[3,3]` terminates under bounds checking because index 3 is used on an array of extent 1.

## Intended implementation rule

The lookup structure must be indexed over the type-code domain, so its extent and construction loop are based on `tmax`. Every event type must resolve to at least one matching `ITYPE_TILLAGE` row before the lookup is used.

## Candidate boundary

The candidate is exactly the historical SWAP-004 hunk re-based after admitted SWAP-002. It does not contain the SWAP-003 `PCLAY` input-domain change and does not alter event timing, tillage constitutive equations, consolidation equations, solver policy or water-balance tolerances.
