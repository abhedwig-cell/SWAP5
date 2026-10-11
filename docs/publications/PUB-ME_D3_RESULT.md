# PUB-ME D3 result

Status: **QUALIFIED_STRUCTURAL_PREVENTION_PENDING_RESULT_POSTIMAGE_REPLAY**

Publication owner: `PUB-ME`

Experiment family: `D3 — wrong-origin candidate is accepted`

## Design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- D3 execution checkpoint: `docs/publications/PUB-ME_D3_EXECUTION_CHECKPOINT.md`
- original execution base: `integration/f-ci-canonical@863f236596129d0ede3e975526553ea7f0a969ed`

The D3 scientific design was frozen before execution. No candidate provenance field was forged or modified and no private/internal commit bypass was introduced.

## Executed paths

The experiment used the public current-canonical kernel execution and commit interfaces with one deterministic qualification-only scalar storage model.

### CLEAN

A valid candidate from lineage 301, revision 0, interval [0,1] committed successfully.

Observed:

- commit status = `KERNEL_COMMIT_STATUS_COMMITTED`;
- revision advanced exactly 0 -> 1;
- committed time advanced exactly 0 -> 1;
- physical storage advanced exactly 0 -> 1;
- the committed candidate was consumed;
- exactly one committed-state mutation was recorded.

### D3-L — wrong lineage

A candidate materialized from lineage 301 was offered to an otherwise matching committed carrier at lineage 302.

Observed:

- commit rejected with `KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH`;
- revision unchanged;
- committed time unchanged;
- physical state bitwise unchanged;
- rejected candidate remained ready;
- exactly one lineage-mismatch rejection and zero committed-state mutations.

### D3-R — stale revision

Two candidates were materialized from the same lineage/revision/time origin. One was committed, advancing the authoritative state to revision 1 and time 1. The still-valid older candidate was then offered to the advanced committed state.

Observed:

- commit rejected with `KERNEL_COMMIT_STATUS_STALE_REVISION`;
- authoritative revision remained 1;
- committed time remained 1;
- physical state remained exactly the endpoint of the first accepted candidate;
- stale candidate remained ready;
- exactly one stale-revision rejection and zero additional committed-state mutations.

### D3-T — wrong accepted time origin

A candidate from lineage 304, revision 0, origin time 0 was offered to a trusted reconstructed committed carrier with the same lineage and revision but committed time 0.25 and identical physical state.

Observed:

- commit rejected with `KERNEL_COMMIT_STATUS_TIME_MISMATCH`;
- revision remained 0;
- committed time remained 0.25;
- physical state bitwise unchanged;
- candidate remained ready;
- exactly one time-origin rejection and zero committed-state mutations.

## Primary classification

**D3 = STRUCTURAL_PREVENTION**

All three preregistered wrong-origin transitions are representable as attempted calls through the admitted public commit interface, but the public contract refuses them before committed scientific state can mutate.

This classification is one of the outcomes explicitly permitted by the preregistration. No internal bypass was added to manufacture an executable wrong-origin commit.

## Qualification evidence

First executable D3 head after a fixture-interface compile correction:

- head: `21fc6228c3fecf7ddcf1f76e3b7e8a5acf0e44eb`
- D3 workflow run: `35285918587`
- D3 job: `105418082758`
- conclusion: SUCCESS
- O0: PASS
- O2: PASS
- O0/O2 stable-output SHA-256: `6e619ebca88ad32592b37e35fd3a41c22321d3392f84b9195e03547ea9b4c853`

Stable markers include:

- `PUB_ME_D3_CLEAN_COMMIT=PASS`
- `PUB_ME_D3_LINEAGE_MISMATCH_STRUCTURAL_PREVENTION=PASS`
- `PUB_ME_D3_STALE_REVISION_STRUCTURAL_PREVENTION=PASS`
- `PUB_ME_D3_TIME_ORIGIN_STRUCTURAL_PREVENTION=PASS`
- `PUB_ME_D3_CLASSIFICATION=STRUCTURAL_PREVENTION`
- `PUB_ME_D3_ORIGIN_AUTHORITY_EXPERIMENT=PASS`

Full canonical qualification on the same executable head:

- run: `35285918570`
- conclusion: SUCCESS

Documentation on the same executable head also passed.

## Compile correction

The first D3 workflow run failed before scientific execution because the qualification fixture extended `kernel_model_t` without overriding the inherited deferred `prepare_interval` method.

The correction added only the missing test-fixture interface binding and a no-physics prepare method. It did not change:

- D3 hypotheses;
- clean or mismatch cases;
- expected statuses;
- kernel production code;
- reference code;
- candidate provenance;
- committed-state semantics.

The corrected fixture then passed both O0 and O2.

## Canonical reconciliation

During execution, canonical advanced beyond the original D3 execution base. The later delta through `b7e48275ebfba5ba888685f7515005c7195d5d73` consisted only of P2E08 publication/test/workflow files and did not modify D3's kernel, transaction, canonical-runtime or reference dependency surface.

PR #210 was retargeted to the then-current canonical before result freeze.

## Scientific interpretation boundary

D3 establishes that the admitted public kernel commit seam structurally prevents three materially different forms of wrong-origin publication:

- wrong lineage;
- stale revision;
- incompatible accepted time origin.

D3 does **not** establish:

- that provenance checks are novel;
- that SWAP5 previously contained a wrong-origin commit defect;
- `UNIQUE_DETECTION` or `EARLIER_DETECTION`;
- hydrologic accuracy;
- D4-D6 outcomes.

For the preregistered PUB-ME publication criterion, D3 counts as a second transition-authority mechanism only if it remains materially distinct from D1 in the final cross-defect analysis. Both currently classify as `STRUCTURAL_PREVENTION`, so the manuscript must not inflate them into independent detection-timing evidence.

## Next permitted action

1. replay D3, documentation and full canonical qualification on this result postimage;
2. if green and canonical-reconciled, admit/close D3 without changing scientific semantics;
3. proceed to D4 as the next independent preregistered defect family;
4. keep the separate D2 follow-up on its own prospective authority and do not use D3 to reinterpret the blocked D2-A result.
