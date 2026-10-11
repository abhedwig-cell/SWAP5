# PUB-ME D4 result

Status: **QUALIFIED_PRIMARY_RESULT_PENDING_POSTIMAGE_ADMISSION**

Publication owner: `PUB-ME`

Experiment family: `D4 — restart captures speculative state`

## Design authority

- D1-D6 preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- execution checkpoint: `docs/publications/PUB-ME_D4_EXECUTION_CHECKPOINT.md`
- execution base: `integration/f-ci-canonical@6a77678b535ed468bdeeb9b67f149be706f0205f`

The D4 classification rules and B1/B2 comparator were frozen before execution.

## Qualified primary execution

Exact executable head before this result record:

- `4ee6bed838b45aa8dfa7970c171735ed684ff134`

Evidence:

- workflow: `PUB-ME D4 speculative restart`
- run: `35286892089`
- job: `105421099902`
- conclusion: **SUCCESS**
- O0: PASS
- O2: PASS
- O0/O2 output identity: PASS
- O0/O2 SHA-256: `ae811b47f368679fcb90118580acc2c92ddf494fd285d045db36817a65d85c8d`

Stable markers:

- `PUB_ME_D4_CLEAN_ROUNDTRIP=PASS`
- `PUB_ME_D4_CLEAN_CONTINUATION=PASS`
- `PUB_ME_D4_B2_PREPUBLICATION_AUTHORITY=DETECTED`
- `PUB_ME_D4_ORIGINATING_TRIAL_ROLLBACK=PASS`
- `PUB_ME_D4_FAULT_ARTIFACT_RECONSTRUCTED=YES`
- `PUB_ME_D4_FAULT_ARTIFACT_RESTORE=ACCEPTED`
- `PUB_ME_D4_B1_ARTIFACT_ROUNDTRIP=DETECTED`
- `PUB_ME_D4_SCIENTIFIC_CONSEQUENCE=NEXT_ENDPOINT_DIVERGES`
- `PUB_ME_D4_MASS_INVARIANT_FALSE_NEGATIVE=PASS`
- `PUB_ME_D4_CLASSIFICATION=EARLIER_DETECTION`
- `PUB_ME_D4_SPECULATIVE_RESTART_EXPERIMENT=PASS`

Documentation on the executable head also passed.

The broad canonical qualification on the executable head was still running when this result record was frozen. The result-bearing head must therefore replay D4, documentation and full canonical qualification before admission.

## Clean control

The normal committed-state persistence path:

1. exported the accepted committed state;
2. restored it into a fresh committed carrier;
3. preserved physical state, lineage, revision and committed time exactly;
4. produced an identical next candidate from source and restored carriers;
5. preserved the same mass/accounting result.

The clean control therefore establishes that the persistence/restart fixture itself is valid.

## Seeded D4 fault

The qualification-only fault modelled an adapter selecting the wrong physical source for restart persistence:

1. accepted state remained physical storage 0 at lineage 401, revision 0, time 0;
2. a real uncommitted candidate for [0,1] reached storage 1;
3. candidate physical state was obtained only through public `candidate%snapshot()`;
4. the trusted persistence reconstruction boundary was given:
   - accepted lineage/revision/time;
   - speculative candidate physical state;
5. the resulting faulty persistence artifact was validly reconstructed;
6. the originating candidate was rolled back;
7. authoritative accepted state remained storage 0 / revision 0 / time 0;
8. the faulty restart artifact was accepted by the normal restore path.

No production or reference source was changed and no candidate-private provenance field was accessed or forged.

## Comparator result

### B2 transition-authority oracle

Before persistence publication, B2 compared the physical continuation payload with the current accepted physical state under the claimed accepted provenance.

Observed:

- accepted physical state = storage 0;
- speculative payload = storage 1;
- claimed lineage/revision/time still described the accepted storage-0 origin;
- B2 therefore detected the authority mismatch **before publication**.

Marker:

`PUB_ME_D4_B2_PREPUBLICATION_AUTHORITY=DETECTED`

### B1 strong conventional restart qualification

The faulty artifact was then restored.

B1's strong restart round-trip state/provenance comparison detected that the restored physical state differed from the authoritative accepted source.

Marker:

`PUB_ME_D4_B1_ARTIFACT_ROUNDTRIP=DETECTED`

Therefore D4 is not `UNIQUE_DETECTION`.

B1 detects the defect after a faulty restart artifact has been reconstructed and restored; B2 detects it before publication of that artifact.

## Primary classification

**D4 = EARLIER_DETECTION**

This is exactly one of the preregistered classifications.

The result is not `UNIQUE_DETECTION` because B1 detects the physical round-trip mismatch immediately after restore.

It is not `STRUCTURAL_PREVENTION` because the public trusted reconstruction plus normal restore path can materialize and restore the qualification-only candidate-derived artifact.

## Scientific consequence

When the faulty artifact is used despite the detected authority violation:

- clean continuation starts from accepted storage 0 and produces next candidate storage 1;
- faulty restart continuation starts from speculative storage 1 and produces next candidate storage 2;
- both continuations individually satisfy the fixture's mass accounting;
- therefore the local mass invariant can remain green while the accepted scientific history has shifted by one speculative step.

This establishes an observable continuation consequence for the seeded D4 fault rather than only an abstract provenance mismatch.

## Relation to D1-D3

Current admitted/qualified classifications are now:

- D1: `STRUCTURAL_PREVENTION`;
- D2: `EARLIER_DETECTION`;
- D3: `STRUCTURAL_PREVENTION`;
- D4: `EARLIER_DETECTION`.

These must not be counted naively as four independent publication wins.

In particular:

- D1 and D3 are both structural-authority mechanisms and their independence must be judged in the final cross-defect analysis;
- D2 and D4 are materially different contamination channels (accepted accounting versus restart persistence) and both show earlier detection rather than unique detection;
- required physical-regime replication remains open;
- D5-D6 may still weaken or falsify the broader hypothesis.

## Interpretation boundary

D4 establishes only the bounded experimental result above.

D4 does **not** establish:

- an existing SWAP5 production restart bug;
- novelty of persistence/restart testing, rollback, provenance or trusted reconstruction;
- that conventional B1 restart tests are inadequate;
- unique detection by B2;
- hydrologic-regime generality;
- publication readiness of PUB-ME.

The seeded fault is qualification-only and intentionally represents an adapter/persistence source-selection mistake.

## Next permitted action

1. replay D4, documentation and full canonical qualification on this result-bearing head;
2. reconcile any live canonical delta;
3. if green and dependency-stable, admit/close D4;
4. proceed to D5 only as a separate preregistered workunit;
5. preserve the required D2 physical-regime replication as an explicit open publication obligation rather than silently treating one fixture as general.
