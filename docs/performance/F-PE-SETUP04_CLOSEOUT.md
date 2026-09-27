# F-PE-SETUP04 closeout — scalable bootstrap production admission

Date: 2026-09-27

Status: `CLOSED_PRODUCTION_ADMISSION_QUALIFIED_PENDING_FINAL_CANONICAL_HEAD`

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

Current-head paired speedups:
- N=1,000: 1.45x;
- N=10,000: 6.42x;
- N=40,000: 32.01x.

At N=40,000, app initialization falls from about 3.59 s to 0.112 s.

## Admission boundary

The dedicated prevalidated registry path is legal only for the freshly initialized production bootstrap after global uniqueness validation.

The generic registry bind path remains the authority for ordinary callers.

## Remaining merge condition

Merge only from a freshly fetched branch head after the final documentation-head current-canonical qualification completes successfully.

Historical unrelated workflow failures remain historical failures; SETUP04 does not waive them.

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
