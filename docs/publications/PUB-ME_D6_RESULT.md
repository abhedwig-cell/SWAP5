# PUB-ME D6 result

Status: **QUALIFIED_PRIMARY_RESULT_PENDING_POSTIMAGE_ADMISSION**

Publication owner: `PUB-ME`

Experiment family: `D6 — rejected/non-authoritative trial external side effect survives`

## Design authority

- D1-D6 preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- D6 start checkpoint: `docs/publications/PUB-ME_D6_EXECUTION_CHECKPOINT.md`
- D6 frozen design: `docs/publications/PUB-ME_D6_PREREGISTERED_DESIGN.md`
- original execution base: `integration/f-ci-canonical@d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`
- reconciled canonical before primary execution: `f2d472cb0e4d935ef39f002d6f21c8d90acf4dd8`

The intervening canonical delta was PUB-P2E10-only and changed no `src/**`, `reference/**`, or D6 dependency surface.

## Qualified primary execution

Exact executable head:

`4127931f56ae654b6ef2cbe540878e32ec3e6e26`

Evidence:

- workflow: `PUB-ME D6 rejected side effect`
- run: `35289475721`
- job: `105428991655`
- conclusion: **SUCCESS**
- O0: PASS
- O2: PASS
- O0/O2 semantic identity: PASS
- O0/O2 output SHA-256: `a97334ba2c311966a189456b1376e847d9132bfca132fc7d164923a81bb41834`

Stable markers:

- `PUB_ME_D6_PRODUCTION_REFERENCE_UNCHANGED=PASS`
- `PUB_ME_D6_MINIMAL_STATE_FIXTURE_BOUND_TO_PRODUCTION_SURFACE=PASS`
- `PUB_ME_D6_CLEAN_ACCEPTED_ONLY_STREAM=PASS`
- `PUB_ME_D6_B2_PREPUBLICATION_AUTHORITY=DETECTED`
- `PUB_ME_D6_B1_END_STREAM_REGRESSION=DETECTED`
- `PUB_ME_D6_ACCEPTED_PHYSICS_UNCHANGED=PASS`
- `PUB_ME_D6_CLEAN_EVENT_COUNT=1`
- `PUB_ME_D6_MUTANT_EVENT_COUNT=2`
- `PUB_ME_D6_REJECTED_EVENT_RATE=3.09999999999999998E-001`
- `PUB_ME_D6_ACCEPTED_EVENT_RATE=1.19999999999999996E-001`
- `PUB_ME_D6_CLASSIFICATION=EARLIER_DETECTION`
- `PUB_ME_D6_REJECTED_SIDE_EFFECT_EXPERIMENT=PASS`

## Selected accepted-only publication seam

D6 uses the current production surface-evaporation publication chain:

- `src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90`;
- `src/runtime/mod_fmr_accepted_commit_receipt.f90`;
- `src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90`.

The production design materializes candidate-bound process attribution while the candidate exists, keeps its precommit publication carrier private, commits the same candidate, and converts the local carrier into a public accepted publication only after a ready accepted receipt exists.

D6 does not modify that production path.

## Scientific fixture

Two candidates A and B were produced from the same accepted origin.

Candidate A:

- received a valid candidate-bound surface-evaporation result;
- bare-soil evaporation rate: `0.31`;
- remained uncommitted.

Candidate B:

- was committed through the real accepted-publication seam;
- bare-soil evaporation rate: `0.12`;
- produced the only valid accepted surface publication.

After B committed, A was stale/non-authoritative and the real production publication/commit path rejected A without an accepted publication.

## Clean control

The clean route did not externally publish candidate A.

Observed event stream:

- event count = 1;
- the only event was the accepted B publication;
- accepted physical endpoint and accepted publication were valid.

Marker:

`PUB_ME_D6_CLEAN_ACCEPTED_ONLY_STREAM=PASS`

## Qualification-only D6 mutant

The mutant inserted one test-only external observer write immediately after A's candidate-bound process result became ready and before any accepted commit receipt/publication existed.

The event sink recorded A's:

- lineage;
- origin revision;
- interval;
- route;
- evaporation values.

The mutant then executed the same accepted B commit and stale A rejection as the clean route.

No production observer API was added.

No `src/**` or `reference/**` file was modified.

## B2 transition-authority result

Before the qualification-only observer mutation, A had only candidate-bound attribution and no accepted commit receipt/publication authority.

The preregistered B2 rule therefore detected the attempted accepted-labelled external side effect **before observer publication**.

Marker:

`PUB_ME_D6_B2_PREPUBLICATION_AUTHORITY=DETECTED`

## B1 strong conventional result

The qualification-only mutant deliberately bypassed the B2 guard to measure the downstream consequence.

Final mutant event stream:

- event count = 2;
- event from rejected/stale A: bare-soil evaporation rate `0.31`;
- event from accepted B: bare-soil evaporation rate `0.12`.

The preregistered strong B1 accepted-event-stream regression detected the extra/non-authoritative event after the bounded execution.

Marker:

`PUB_ME_D6_B1_END_STREAM_REGRESSION=DETECTED`

B1 therefore detects D6; this is not unique detection.

## Accepted science remained unchanged

The qualification-only observer side effect did not change:

- final committed revision/time;
- accepted physical state digest;
- accepted B surface publication.

Clean and mutant accepted physical outcomes matched.

Marker:

`PUB_ME_D6_ACCEPTED_PHYSICS_UNCHANGED=PASS`

This is the intended D6 semantic distinction: the accepted physical simulation can remain correct while an externally visible event stream contains a result from computation that never became accepted scientific history.

## Primary classification

**D6 = EARLIER_DETECTION**

B2 detects the authority violation before external side-effect mutation.

B1 detects the contaminated accepted-event stream after execution.

D6 is not `UNIQUE_DETECTION`.

D6 is not `STRUCTURAL_PREVENTION` because the qualification-only harness can explicitly bypass the accepted-only observer rule outside the protected production publication seam.

## Compile-fixture history

Three workflow attempts before the primary execution failed **before scientific D6 execution** while closing unrelated current compile dependencies:

1. run `35289083019`, job `105427794961`: missing accepted-trajectory directional sensitivity dependency;
2. run `35289158822`, job `105428034500`: missing accepted-trajectory directional publication dependency;
3. run `35289232065`, job `105428258864`: the full serialized backend pulled an unrelated bottom-thermal carrier dependency.

No D6 result was observed before the final compile-fixture simplification.

The successful qualification build uses a test-only minimal `mod_fmr_serialized_reference_backend` carrier exposing only the hydraulic base fields required by the exact production process-view/materialization path. The runner fail-closes if those production fields or clone contract drift.

The real current-canonical kernel, transaction, materialization, commit-receipt and accepted-publication sources are compiled unchanged.

## Relation to D1-D5

Current bounded classifications are:

- D1: `STRUCTURAL_PREVENTION`;
- D2: `EARLIER_DETECTION`;
- D3: `STRUCTURAL_PREVENTION`;
- D4: `EARLIER_DETECTION`;
- D5: `EARLIER_DETECTION`;
- D6: `EARLIER_DETECTION`.

These are not six independent publication wins.

Mechanistically:

- D1 and D3 are structural state/provenance prevention mechanisms;
- D2 is accepted accounting contamination;
- D4 is speculative restart/persistence contamination;
- D5 is numerical-workspace misuse as physical retry origin;
- D6 is external accepted-history/event contamination.

D2, D4, D5 and D6 each show earlier detection, not unique detection.

A final cross-defect independence analysis is still required before a publication-level conclusion.

## Interpretation boundary

D6 establishes only the bounded experiment above.

D6 does **not** establish:

- an existing SWAP5 production defect;
- novelty of observer callbacks, commit receipts, rollback or accepted-only publication;
- that conventional B1 testing is inadequate;
- unique detection by B2;
- hydrologic-regime generality;
- publication readiness of PUB-ME by itself.

The contamination operator is qualification-only.

## Outstanding publication obligations

Before elevating the full D1-D6 study:

1. replay D6 on this result-bearing postimage;
2. complete documentation and full canonical qualification;
3. reconcile live canonical delta and admit/close D6 if dependency-stable;
4. perform the preregistered cross-defect independence analysis;
5. retain the explicit D2 physical-regime replication obligation;
6. update the novelty/literature assessment before manuscript claim freeze;
7. only if the primary RQ remains supported, consider the gated RQ1b selective-requalification study.

## Next permitted action

Run exact-head D6, documentation and full canonical qualification on the result-bearing head.

Do not alter D6 scientific semantics or reinterpret EARLIER_DETECTION as UNIQUE_DETECTION.
