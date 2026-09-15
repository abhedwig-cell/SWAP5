# F-WOF-PP01 independent potential-production oracle

F-WOF-PP01 qualifies the **verified SWAP 4.3.1 WOFOST 8.1 Fortran donor** against ten immutable
Spring Barley potential-production trajectories generated independently with PCSE 6.0.13 / WOFOST 8.1.

This is deliberately donor-first. The current SWAP5 crop path is a later migration target and is not
silently treated as if it already exposed the complete historical WOFOST81 donor state.

The source oracle artifact is `tests_Wofost81_PP.zip`, SHA-256
`99a67a0e5f6bd0881b97950a2ff3fe0f387c0a9e0553f2e36197077fbc15d145`.
The donor artifact is `SWAP_4.3.1_WOFOST81_WORKING_FINAL_13B.zip`, SHA-256
`4e0bf97bca7f3f8716e5bcf46a5dc9bb6b08436304b032d60adc3757491d94dc`.

## Qualified result

All ten cases complete normally and deterministically. The following WOFOST81-owned crop outputs
pass every supplied YAML tolerance at every compared crop-state observation:

`DVS`, `LAI`, `NamountLV`, `NamountRT`, `NamountSO`, `NamountST`, `NuptakeTotal`,
`TAGP`, `TWLV`, `TWRT`, `TWSO`, `TWST`.

The largest absolute crop-state discrepancy is `7.276e-12` for `TAGP`, versus its YAML tolerance
of `0.1`.

`RD` and `TRA` are not silently omitted. They fail if compared directly to SWAP `rd` and
`iptra_day`, because the donor explicitly retains SWAP rooting and hydrology as separate
SWAP-specific interfaces rather than WOFOST81 crop-state owners. The full 14-field YAML surface is
therefore **not** claimed as one conformance PASS.

See:
- `REFERENCE_MANIFEST.json` for immutable oracle hashes and tolerances;
- `MAPPING_CONTRACT.md` for the qualified semantic boundary;
- `F-WOF-PP01_DONOR_QUALIFICATION.md` and `.json` for the executed ten-case evidence.

## Qualification-only boundary adapter

The PCSE cases prescribe non-limiting external `SM=0.3` and `NAVAIL=100`. The qualification copy
therefore sets crop `RELTR=1` and returns the donor's bounded `NdemandSoil` as `NsupplySoil`.
The existing WOFOST81 crop equations, N request, `RNUPTAKEMAX`, translocation, state update and
balance checks are retained unchanged. No SWAP5 production source and no immutable donor/oracle
artifact is modified.

## Next use

The qualified 12-output donor/oracle surface is now the immutable scientific reference for a
separate SWAP5 WOFOST81 migration-preservation campaign. `RD`/`TRA` require a separately defined
interface-equivalence contract if they are to be qualified in the future.
