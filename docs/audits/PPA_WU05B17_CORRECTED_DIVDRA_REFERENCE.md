# PPA-WU05B17: bounded corrected DIVDRA reference

## Demonstrated numerical omission

[B16 original-owner evidence](PPA_WU05B16_DIVDRA_REFERENCE_OWNER.md) demonstrates that separate infiltration includes positive unsaturated transmissivity in its total denominator but drops its nodal contribution when `KDuns <= 1e-8`. The independent geometric integral identifies the same omission. The correction follows accepted ADR-0005 through a separately persisted source-bound preregistration.

## Minimal isolated overlay

`FROST-DIVDRA-02` reconstructs the complete unchanged original DIVDRA with one guard replacement: `KDuns > 1.d-8` becomes `KDuns > 0.d0`. The existing integral formula computes every positive unsaturated contribution; zero remains on its original branch. The original reference source is immutable. CRLF and inherited trailing spaces in the reconstructed artifact are intentionally retained; whitespace checks exclude only this byte-exact artifact and its textual patch, while the hash-guarded single replacement verifies their fidelity.

All sign, geometry, anisotropy, infiltration-depth, small-scalar and FrozenBounds scalar/bottom policies stay fixed. No production source changes. The artifact manifest records that it was generated before qualification; current qualification status belongs to the work-unit status and qualification record.

## Completed qualification

Fresh complete original and corrected processes execute all **4536** preregistered cases at O0 and O2: **18144** case executions. Original output reproduces the immutable B16 output exactly; both variants are O0/O2 byte-identical.

Exactly **192** cases change, each predicted by active negative scalar, separate infiltration and positive unsaturated transmissivity no greater than 1e-8. Initial nodal proposal, final scalar and final bottom values remain exact. The other **4344** cases are byte-identical to the original. All **1296** original tiny-scalar initial early returns are retained.

Maximum independent conservative partition error is **2.7755575615628914e-17** cm/day. Maximum corrected final nodal/scalar residual is **4.163336342344337e-17**, versus **2.43440267944095e-11** in the original. Invalid source, source overwrite and occupied-output guards all fail closed without modifying their targets.

## Scope and evidence

[Immutable complete replay](evidence/PPA_WU05B17_CORRECTED_REFERENCE_REPLAY.json.gz) retains all original/corrected outputs, input cases, actual reconstructed source, negative guard logs and source hashes. `integration/audits/PPA_WU05B17_REF_QUALIFICATION.json` and `PPA_WU05B17_REF_STATUS.json` bind the patch, preregistration, compiled checkpoint and completed gates.

This qualifies a bounded single-level corrected-reference process composition. It does not promote a global B1 snapshot, qualify multilevel redistribution, establish full legacy simulation equivalence or admit a SWAP5 frost redistribution runtime. Later production integration still requires an explicit physical contract, immutable-trial generation, one final nodal sink, separate bottom owner, full/half regeneration and hard-mass/rejection/restart/receipt gates. Aggregate frost migration remains open.
