# WOFOST admitted runtime scope

WOFOST is part of the SWAP5 Status-A baseline only through its **bounded qualified runtime scope**. The current claim concerns the admitted production path and its preservation evidence; it is not a blanket statement about every WOFOST interface, crop configuration or external implementation.

## Scientific role

Within the admitted composition, WOFOST supplies crop-development/production behaviour to the SWAP application through the qualified runtime path. The crop component interacts with the soil-water system through the interfaces and state exchanges admitted by the owning capability records.

F-DOC20 does not alter that scientific coupling. Its purpose here is to make the current boundary readable for reviewers.

## Status-A position

The WOFOST runtime capability is contained in the pinned scientific production baseline `50346642…`. F-CI89 is the current capability-specific runtime qualification/admission authority named by the Status-A traceability map. Same-tree scientific WOFOST smoke and extended checks are inherited by the Status-A release-readiness record.

The exact implementation and qualification details remain distributed across the owning WOFOST records; [Status-A traceability](../status-a/TRACEABILITY.md) is the navigation authority.

## SWAP 4.3.1 / Python WOFOST equivalence

The admitted runtime scope must not be confused with a complete proof that the Fortran WOFOST path in SWAP5 is scientifically equivalent to every independent WOFOST 8.1 implementation or to a particular Python reference experiment.

The review portal therefore keeps those questions separate:

- **Status-A WOFOST runtime admission**: current and admitted within its bounded contract;
- **additional SWAP 4.3.1 / Python WOFOST equivalence evidence**: useful supplementary validation when a properly defined experiment is accepted.

See [SWAP 4.3.1 and SWAP5 equivalence](../review/SWAP431_EQUIVALENCE.md) for the general equivalence discipline.

## Transaction and persistence considerations

Any crop state that is part of accepted model continuation must obey the same committed/candidate ownership rule as the rest of the admitted runtime. A future change that introduces new persistent crop state, retry-sensitive state or restart dependencies must establish those dependencies explicitly rather than inheriting coverage by assumption.

## Explicit nonclaims

The Status-A WOFOST row does **not** claim:

- a broad stable public WOFOST API;
- unrestricted compatibility with arbitrary external WOFOST implementations;
- proof of all crop-model options or crop files;
- automatic restart/MultiSWAP qualification for newly introduced crop state;
- application-wide SWAP 4.3.1 equivalence solely from the existence of F-CI89.

## Review questions

For a WOFOST-sensitive change, ask:

1. Is the change inside the admitted runtime path or a new mode?
2. Are soil-water/crop exchanges unchanged in meaning, units and timing?
3. Does new state affect restart, retry or MultiSWAP ownership?
4. Which scientific smoke/extended checks protect the changed surface?
5. Is an equivalence claim being made that requires an independent reference experiment rather than only regression evidence?