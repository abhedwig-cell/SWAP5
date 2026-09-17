# PUB-ME D4 execution checkpoint

Status: **PREREGISTERED_EXECUTION_DESIGN_BEFORE_D4_RUN**

Publication owner: `PUB-ME`

Experiment family: `D4 — restart captures speculative state`

## Immutable scientific design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- original D4 semantics: a persistence/restart artifact derived from candidate state before final acceptance must not become the source of a later authoritative continuation.

## Execution base

- `integration/f-ci-canonical@6a77678b535ed468bdeeb9b67f149be706f0205f`

Relevant current-canonical surfaces:

- `src/kernel/mod_kernel_transactions.f90`
- `src/kernel/mod_kernel_committed_persistence.f90`

The normal persistence exporter accepts only `kernel_committed_state_t`.
The trusted reconstruction bridge accepts a fully decoded physical continuation state plus explicit committed provenance and is therefore the bounded public surface on which an adapter-selection error can be modelled without accessing candidate-private fields.

## Experimental model

Use a deterministic qualification-only scalar storage model behind the public `kernel_model_t` seam.

- initial accepted storage = 0;
- interval [0,1] increases storage by exactly 1;
- mass input = 1 and mass output = 0;
- temporal error = 0;
- all clean execution and restart paths must be exact under O0 and O2.

This fixture is not a hydrologic-regime experiment. D4 tests persistence authority.

## CLEAN control

1. initialize authoritative committed state:
   - lineage 401;
   - revision 0;
   - committed time 0;
   - physical storage 0;
2. export through `export_kernel_committed_state` using fixed positive layout id 4101;
3. restore that snapshot into a fresh committed carrier;
4. require source and restored:
   - lineage equal;
   - revision equal;
   - committed time equal;
   - physical state bitwise equal;
5. execute the same [0,1] continuation from both source and restored carrier;
6. require candidate endpoints, mass/accounting, and candidate provenance to be identical.

Clean control failure invalidates D4 interpretation.

## D4 fault operator

The fault is qualification-only and represents an adapter/persistence hook choosing the wrong physical source.

1. initialize accepted committed state `S0` as above;
2. execute a real kernel interval [0,1] from `S0` and materialize candidate `C1`;
3. do **not** commit `C1`;
4. obtain candidate physical state only through public `candidate%snapshot()`;
5. before candidate rollback, call `reconstruct_kernel_persistence_snapshot_trusted` with:
   - schema version = current kernel persistence schema;
   - layout id = 4101;
   - lineage = accepted lineage 401;
   - revision = accepted revision 0;
   - committed time = accepted time 0;
   - decoded physical state = the speculative candidate snapshot;
6. this is the seeded faulty restart artifact;
7. roll back `C1` through `kernel_executor_t%rollback_candidate`;
8. verify the original committed state is still storage 0 / revision 0 / time 0;
9. restore the faulty artifact into a fresh committed carrier;
10. if restore succeeds, execute [0,1] from:
    - the untouched authoritative `S0`;
    - the faulty restored carrier.

No candidate provenance field is forged or read privately. The trusted bridge is used exactly as an adapter would use it after decoding an external continuation record. The intentional defect is selecting speculative physical state as that decoded continuation state.

## Comparator B1 — strong conventional qualification

B1 is not output-only. It includes:

1. persistence round-trip structural success;
2. full physical source-versus-restored state comparison;
3. lineage/revision/time comparison;
4. clean restart/split-run continuation comparison;
5. mass/accounting checks for subsequent continuation;
6. deterministic O0/O2 replay.

For the mutant, record the first B1 detection boundary:

- `B1_ARTIFACT_ROUNDTRIP`: restored physical state differs from the accepted source immediately after restore;
- `B1_CONTINUATION`: no immediate round-trip comparison detects it, but subsequent continuation diverges;
- `B1_NOT_DETECTED`: bounded B1 checks remain green.

The experiment must not suppress an applicable B1 check merely to create a B2 advantage.

## Comparator B2 — transition-authority qualification

B2 contains B1 plus the direct pre-publication authority rule:

> The physical continuation encoded as committed restart state must be identical to the current accepted committed physical state from which its lineage/revision/time provenance is claimed.

Before accepting the seeded artifact, compare:

- committed source physical digest/value;
- candidate-derived decoded physical digest/value;
- claimed lineage/revision/time.

A physical mismatch under identical claimed accepted provenance is a direct D4 authority violation before restart publication.

The normal typed exporter additionally demonstrates that direct candidate export is structurally unavailable, but this fact alone does not determine the D4 classification because the trusted reconstruction bridge remains a legitimate adapter boundary.

## Frozen classifications

After execution classify exactly one of:

- `STRUCTURAL_PREVENTION`: the public trusted persistence path refuses the candidate-derived artifact before it can become a valid restart carrier;
- `NO_INCREMENTAL_VALUE`: B1 detects the fault at an equally protective pre-publication boundary;
- `EARLIER_DETECTION`: B2 rejects the candidate-derived committed claim before publication, while B1 first detects only after a faulty restart artifact has been restored or used;
- `UNIQUE_DETECTION`: bounded B1 remains green while B2 detects the authority mismatch;
- `D4_AUTHORITY_FAILURE`: the artifact is accepted/restored and neither the declared B2 oracle nor expected accepted-state checks identify the mismatch.

Do not change the classification rule after observing results.

## Primary outcomes

Record:

- clean export/restore status;
- clean source/restored physical identity;
- clean lineage/revision/time identity;
- candidate physical value before rollback;
- committed physical value before/after rollback;
- faulty artifact reconstruction status;
- B2 pre-publication authority-oracle result;
- faulty restore status;
- faulty restored physical value;
- B1 first-detection boundary;
- clean and faulty continuation endpoints;
- continuation mass/accounting;
- candidate rollback diagnostics;
- O0/O2 output identity.

## Scientific consequence criterion

If the faulty artifact can be restored, demonstrate the counterfactual scientific consequence by continuing the same interval from clean and faulty restart origins.

Expected deterministic example, not a required numerical result:

- clean accepted source storage 0 -> next candidate storage 1;
- candidate-derived faulty restart storage 1 -> next candidate storage 2.

The actual observed values, not this expectation, determine the result.

## Hard exclusions

- no `src/**` or `reference/**` mutation;
- no candidate-private-field access;
- no private kernel persistence bypass;
- no weakening of persistence validation;
- no D5/D6 execution;
- no claim that restart testing, persistence typing, or provenance itself is novel;
- no claim that the seeded adapter mistake exists in SWAP5 production.

## Next permitted action

Implement exactly the CLEAN and D4 fault paths above using current public APIs.
If the trusted reconstruction path cannot materialize the fault as preregistered, record `STRUCTURAL_PREVENTION`; do not introduce a private test hook.
