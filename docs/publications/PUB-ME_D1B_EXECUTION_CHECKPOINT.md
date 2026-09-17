# PUB-ME D1-B detection-timing experiment checkpoint

Status: **PREREGISTERED_EXECUTION_DESIGN_BEFORE_MUTANT_RUN**

Publication owner: `PUB-ME`

Experiment family: `D1 — rejected candidate mutates committed physical state`

Substudy: **D1-B — B1 versus B2 detection timing under a qualification-only rejected-state contamination fault**

## Immutable scientific design authority

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- primary interpretation categories: `NO_INCREMENTAL_VALUE`, `EARLIER_DETECTION`, `UNIQUE_DETECTION`, `STRUCTURAL_PREVENTION`

D1-A has already demonstrated `STRUCTURAL_PREVENTION` for the admitted public execution surface. D1-B is not allowed to overwrite that result. It asks a different question: if the authority boundary is deliberately violated by a qualification-only faulty adapter/persistence model, when do B1 and B2 first detect the scientific contamination?

## Execution base

- `integration/f-ci-canonical@d0a41c39d7ff95db99bcf8360ac9b474fdf164d7`
- real physical route: same Reference / serialized FMR path used by PUB-P1E02
- rejection mechanism: external full-versus-two-half temporal assessment with zero temporal tolerance after real HeadCalc execution

No production or reference source may be changed.

## Frozen fault model

After a real physical rejection has completed without an accepted commit, a qualification-only faulty adapter emulates one forbidden rejected-state write-through by constructing a contaminated committed carrier with:

- identical lineage id;
- identical revision;
- identical committed time;
- identical profile except node 1 pressure head;
- node 1 pressure head changed from `-75.0 cm` to `-74.5 cm`;
- node 1 water content recomputed from the same frozen Mualem-van Genuchten parameters so the injected state remains constitutively consistent.

The fault injector uses the existing trusted reconstruction boundary only inside the publication test harness. It does not claim that the admitted runtime currently performs this operation. The purpose is to instantiate the preregistered D1 semantics without adding a production backdoor.

The contamination magnitude and location are frozen before execution and may not be tuned after observing results.

## Matched paths

### CLEAN

1. initialize accepted state `S0`;
2. execute the real rejecting physical interval;
3. retain the unchanged committed carrier;
4. execute one matched accepted continuation interval.

### MUTANT

1. initialize the same accepted state `S0`;
2. execute the same real rejecting physical interval;
3. apply the frozen qualification-only physical contamination while preserving revision/time;
4. execute the same matched accepted continuation interval.

Forcing, parameters, grid, numerical configuration and continuation duration are identical between paths except for the injected D1 physical state difference.

## B1 observations frozen before execution

B1 is the strong conventional baseline but excludes a direct candidate-to-accepted physical-state immutability oracle.

At the rejection boundary B1 observes:

- both runs report post-solver transaction rejection;
- both publish no completed/committed interval;
- both report zero accepted transaction count;
- both publish zero accepted in/out transfer;
- both preserve the same committed revision and time metadata.

B1 is classified as **not detecting at the boundary** only if all these observations remain matched despite the physical contamination.

The next B1 comparison point is the endpoint of the matched accepted continuation. B1 detects there if the clean and mutant accepted physical endpoints diverge beyond exact bit identity.

No B1 check may be removed because it detects the mutant.

## B2 oracle frozen before execution

B2 adds one direct transition-authority assertion immediately after the rejected trial and before continuation:

> The authoritative committed physical state must be identical to the accepted state that existed before the rejected trial.

B2 detects the mutant when pressure-head or water-content identity differs at this boundary despite unchanged revision/time and zero accepted ledger publication.

## Continuation configuration

The continuation starts again at committed time 0 because the rejected trial did not advance accepted time.

Frozen continuation request:

- duration: `0.25 day`;
- same zero-flux forcing and physical parameterization as the rejection control;
- external full-versus-two-half mode;
- temporal tolerance: `1.0e6`;
- mass tolerance: `1.0e-10 cm`;
- retry scale: `0.5`;
- max retries: `4`;
- max committed substeps: `1`.

If the clean continuation itself cannot be accepted under these frozen settings, D1-B is `BLOCKED_CONTINUATION_CONFIGURATION`; do not tune the contamination magnitude or choose a favorable alternate case after seeing the result. A separately preregistered remediation would be required.

## Primary outcomes

Record:

- physical HeadCalc calls before rejection;
- B1 boundary match;
- B2 boundary detection;
- clean continuation accepted status;
- mutant continuation accepted status;
- maximum absolute endpoint pressure-head difference;
- maximum absolute endpoint water-content difference;
- first detection layer/time.

## Interpretation rule

- `EARLIER_DETECTION`: B1 boundary observations remain matched, B2 detects immediately, and B1 detects only at the later accepted continuation endpoint.
- `UNIQUE_DETECTION`: B2 detects but the complete frozen B1 path does not.
- `NO_INCREMENTAL_VALUE`: B1 detects the D1 fault at the same boundary without relying on the explicit transition-authority assertion.
- `BLOCKED_CONTINUATION_CONFIGURATION`: clean matched continuation cannot be executed as frozen.

No claim stronger than the observed category is permitted.

## Hard exclusions

- no `src/**` or `reference/**` mutation;
- no production fault hook;
- no weakening of private state ownership;
- no tuning after result inspection;
- no D2-D6 execution;
- no claim that this synthetic fault is evidence of an existing SWAP5 production bug;
- no standalone PUB-ME support claim from D1-B alone.
