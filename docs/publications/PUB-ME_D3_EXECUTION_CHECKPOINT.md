# PUB-ME D3 execution checkpoint

Status: **PREREGISTERED_EXECUTION_DESIGN_BEFORE_D3_RUN**

Publication owner: `PUB-ME`

Experiment family: `D3 — wrong-origin candidate is accepted`

## Immutable scientific design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- original D3 semantics: a candidate from stale revision, wrong lineage or incompatible accepted time origin must not be committed as successor of the current accepted state.

## Execution base

- `integration/f-ci-canonical@863f236596129d0ede3e975526553ea7f0a969ed`

Current kernel commit authority exposes:

- `KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH = 3`;
- `KERNEL_COMMIT_STATUS_STALE_REVISION = 4`;
- `KERNEL_COMMIT_STATUS_TIME_MISMATCH = 5`.

The candidate's provenance fields are private and may only be obtained by materializing a candidate through the admitted kernel execution path.

## Experimental model

Use a minimal deterministic qualification-only physical model behind the existing public `kernel_model_t` seam.

The model:

- has one scalar physical storage state;
- advances storage by exactly the interval duration;
- reports matching mass input;
- has zero temporal error;
- exposes no special production or coupling behavior.

This fixture is not a scientific hydrologic model and is used only to exercise the generic provenance/commit contract. D3 is a state-authority mechanism experiment, not a hydrologic-regime experiment.

## Clean control

1. initialize committed state `A0` with lineage 301, revision 0, committed time 0;
2. materialize candidate `C_A` for [0,1];
3. commit `C_A` back to `A0`;
4. require:
   - commit status = `KERNEL_COMMIT_STATUS_COMMITTED`;
   - revision becomes 1 exactly once;
   - committed time becomes 1;
   - committed physical storage equals the candidate endpoint.

The clean control must pass before any mismatch classification is interpreted.

## D3-L — wrong lineage

1. initialize source committed state with lineage 301, revision 0, time 0;
2. materialize valid candidate `C_L` for [0,1];
3. independently initialize target committed state with lineage 302, revision 0, time 0 and identical physical state;
4. attempt to commit `C_L` to lineage 302.

Frozen expected authority result:

- `did_commit = false`;
- status = `KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH`;
- target revision remains 0;
- target time remains 0;
- target physical state remains bitwise unchanged;
- candidate remains ready because no commit consumed it;
- diagnostics increment exactly one lineage-mismatch rejection and no committed-state mutation.

## D3-R — stale revision

1. initialize committed state with lineage 303, revision 0, time 0;
2. materialize two valid candidates `C_old` and `C_new` from the same accepted origin over [0,1];
3. commit `C_new` successfully, advancing committed revision to 1 and time to 1;
4. attempt to commit still-valid `C_old`.

Frozen expected authority result:

- `did_commit = false`;
- status = `KERNEL_COMMIT_STATUS_STALE_REVISION`;
- revision remains 1;
- time remains 1;
- committed physical state remains exactly the endpoint published by `C_new`;
- stale candidate remains ready;
- diagnostics record one stale-revision rejection and no additional committed-state mutation.

Because revision is checked before time origin, this case is classified as stale revision even though the accepted time has also advanced.

## D3-T — wrong accepted time origin at same lineage/revision

1. initialize source committed state with lineage 304, revision 0, time 0;
2. materialize valid candidate `C_T` for [0,1];
3. obtain an independent clone of the source physical state;
4. use the existing trusted reconstruction boundary to create a target committed carrier with:
   - same lineage 304;
   - same revision 0;
   - committed time 0.25;
   - identical physical state;
5. attempt to commit `C_T`.

Frozen expected authority result:

- `did_commit = false`;
- status = `KERNEL_COMMIT_STATUS_TIME_MISMATCH`;
- revision remains 0;
- committed time remains 0.25;
- target physical state remains bitwise unchanged;
- candidate remains ready;
- diagnostics record one time-origin rejection and no committed-state mutation.

The trusted reconstruction boundary is used only to instantiate a valid persisted accepted origin with a different time. It is not used to forge candidate provenance.

## Comparator and classification

For D3, a wrong-origin candidate can only be meaningfully tested if the invalid operation can be attempted through the admitted public commit seam.

The preregistered D3 rule already states:

> if the admitted API structurally rejects this, classify D3 as prevented-by-contract rather than injecting an internal bypass.

Therefore:

- all three mismatch paths fail before committed-state mutation -> `STRUCTURAL_PREVENTION`;
- any mismatch path commits or mutates accepted state -> D3 authority failure, not a positive publication result;
- do not add an internal bypass merely to produce an executable mutant.

B1/B2 detection timing is not forced for D3 if the invalid transition is structurally refused by the public commit contract.

## Primary outcomes

Record for each path:

- candidate ready before commit;
- commit status;
- did_commit;
- committed revision before/after;
- committed time before/after;
- committed physical-state digest/value before/after;
- candidate ready after rejected commit;
- commit-rejection diagnostics;
- committed-state mutation count.

Run under O0 and O2 and require identical output.

## Hard exclusions

- no `src/**` or `reference/**` mutation;
- no candidate-private-field access or forgery;
- no internal kernel bypass;
- no weakening of lineage/revision/time checks;
- no D4-D6 execution;
- no claim that provenance checking itself is novel;
- no claim that D3 represents an existing SWAP5 production bug.

## Next permitted action

Implement exactly the clean, lineage, stale-revision and time-origin paths above using the public current-canonical kernel API. If a required public operation is unavailable, record the blocker rather than introducing a private test hook.
