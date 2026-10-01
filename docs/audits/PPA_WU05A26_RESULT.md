# PPA-WU05-A26 result — bounded live RFM Reference runtime

Date: 2026-10-01
Status: QUALIFIED_ADMISSION_CANDIDATE

Reconciled canonical base: e2d18564383e1350b0b9a68af0eaf668dac784af
Qualified content postimage: 2a77a36411ecedf3840566de1f5130322dc417fe
Qualification run: 36922167441 — SUCCESS
Qualification job: 110570615817 — SUCCESS

Current branch head after a tree-neutral compile-order metadata commit: 44f4225b512fde778558b8bac7395346d6eea250.
Git compare reports zero changed files between 2a77a364 and 44f4225b; therefore the qualified source tree is unchanged.

## Qualified production composition

Bounded scope:
- unponded;
- runoff-free;
- B1.10 flux-controlled surface regime;
- explicit caller-owned RFM parameters and endpoint geometry;
- no simultaneous standard SWAP macropore execution;
- Reference Richards matrix solver;
- accepted-state-frozen first-order operator split;
- candidate-only RFM state;
- distinct MB deep receipt;
- fail closed outside scope.

Composition:
1. accepted RFM state and accepted matrix hydraulic view;
2. A13 surface event age;
3. A12/A11 hydraulic activation;
4. A15 B1.10 effective surface receipt and matrix/preferential partition;
5. A17 endpoint routing;
6. A26H wall hydraulic history binding;
7. A26J endpoint storage geometry;
8. A26K hydrostatic IC macropore head;
9. A22A stored IC endpoint release;
10. A26I leading MB fast-through route as distinct deep receipt, with no passage wall exchange;
11. A23 whole-column ledger;
12. A24 internal matrix-source provider;
13. real Reference Richards candidate trial;
14. transaction owner decides accept/reject.

This remains an explicit first-order split, not a monolithic nonlinear RFM/Richards solve.

## Qualification evidence

Run 36922167441 passed in one reconciled gate:
- PPA-WU05-A26 live trial preparer;
- serialized backend O0/O2 compile/preservation gate;
- real Reference Richards source binding.

Earlier focused evidence additionally qualified:
- production composer and A23 closure;
- accepted-state immutability and bit-identical replay;
- zero-RFM/reference limit;
- timestep-refinement behavior;
- checkpoint/RFM state carrier;
- unsupported surface regimes fail closed;
- A26H wall-history ownership;
- A26J storage geometry;
- A26K hydrostatic endpoint head.

## Reconciliation

Canonical advanced substantially after the original A26 branch. The reconciled postimage preserves the later standard-macropore reduction continuation and PERCH work. RFM requires FMR_NUMERICAL_CONTINUATION_NONE and cannot consume the standard-macropore reduction continuation simultaneously.

The only reconcile failures were focused compile-list topological-order defects introduced by new canonical dependencies. No RFM physics oracle failed.

## Decision

    A26 = QUALIFIED_ADMISSION_CANDIDATE
    A20_RFM_GUARD = REPLACED_ONLY_WITH_LIVE_COMPOSITION
    STANDARD_MACROPORE_COEXECUTION = REJECTED
    MB_FAST_THROUGH_WALL_EXCHANGE = NOT_IN_LEADING_PRODUCTION_ROUTE
    MB_DEEP_RECEIPT = DISTINCT
    IC_MACRO_HEAD = HYDROSTATIC_FROM_EXPLICIT_STORAGE_GEOMETRY
    ACCEPTED_ORIGIN_IMMUTABLE = QUALIFIED
    RETRY_REPLAY = QUALIFIED
    ZERO_RFM_LIMIT = QUALIFIED
    TIMESTEP_REFINEMENT = QUALIFIED
    REFERENCE_RICHARDS_BINDING = QUALIFIED
    NEXT = canonical admission and post-merge preservation
