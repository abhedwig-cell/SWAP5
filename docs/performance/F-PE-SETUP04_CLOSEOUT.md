# F-PE-SETUP04 closeout — scalable bootstrap production admission

Date: 2026-09-27

Status: `CLOSED_PRODUCTION_ADMISSION_QUALIFIED`

PR:
`#681 — F-PE-SETUP04: production admit scalable bootstrap identity binding`

## Outcome

SETUP04 production-admits the scalable large-N bootstrap mechanism qualified by SETUP03.

The admission preserves:
- ordinary registry bind behavior for generic callers;
- exact participant identity and handle ordering;
- duplicate tile/ledger fail-closed behavior;
- q/tangent semantics;
- TEMPORAL08 policy;
- MULTI04 worker-local execution and scaling;
- transaction/candidate/ledger/publication ownership.

## Performance

Final qualification-head paired speedups:
- N=1,000: 1.45x;
- N=10,000: 6.42x;
- N=40,000: 32.01x.

At N=40,000, app initialization falls from about 3.59 s to 0.112 s.

## Admission boundary

The dedicated prevalidated registry path is legal only for the freshly initialized production bootstrap after global uniqueness validation.

The generic registry bind path remains the authority for ordinary callers.

## Final qualification

On the documentation closeout head:
- SETUP04 production admission: PASS;
- PPA-WU01 production bootstrap: PASS;
- generic participant registry: PASS;
- TEMPORAL08 production admission: PASS;
- MULTI04 production application-context identity/scaling: PASS;
- ZERO-WASTE01: PASS;
- F-CI110 reconstructed performance admission: PASS;
- current F-CI canonical qualification: PASS;
- documentation: PASS.

Historical unrelated workflow failures remain historical failures; SETUP04 does not waive or reinterpret them.

## Merge condition

Merge only from a freshly fetched head with the relevant final checks still green and no parallel branch change.

## No change

No change to:
- Richards equations;
- constitutive equations;
- c=0.65 temporal policy;
- BALTOL02;
- nonlinear tolerances;
- retry policy;
- tangent mathematics;
- worker scheduler;
- MODFLOW equations;
- mass/transaction/publication semantics.

## Closure

`CLOSED_PRODUCTION_ADMISSION_QUALIFIED`
