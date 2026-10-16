# PUB-ME preregistered D1-D6 transition-authority experiment matrix

Status: **PREREGISTERED_DESIGN_BEFORE_EXECUTION**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Design freeze date: 2026-09-18

Related literature boundary: `PUB-ME_LITERATURE_REVIEW_PASS4_TEMPORAL_STATE_TRANSITION.md`

## 1. Primary research question

> During staged modernization of a mature time-stepped process model, do explicit transition-authority contracts at the candidate-to-accepted state boundary provide incremental protection against scientifically consequential contamination faults beyond a strong baseline of established scientific-software testing?

The experiment does **not** test whether rollback, retry, regression testing, mutation testing or restart are novel. They are prior art.

The experiment tests incremental protection against a bounded class of semantic faults in which non-authoritative computation affects accepted scientific history.

## 2. Primary hypothesis

### H-ME-TA

Explicit transition-authority contracts provide observable incremental protection against at least some scientifically consequential state-history contamination faults beyond a credible conventional scientific-software qualification baseline.

`Incremental protection` means one or more of:

- the production contract makes a fault unrepresentable through the admitted interface;
- a direct transition-authority oracle detects the fault before accepted scientific history is changed;
- the authority oracle detects a fault that the strong baseline does not detect for the same bounded execution;
- the authority oracle detects the fault materially earlier than downstream output divergence, before the contaminated state can propagate.

The experiment is allowed to reject H-ME-TA.

## 3. Explicit null / unfavorable result

### H0-ME-TA

A strong baseline of established regression, conservation, restart and integration testing provides effectively the same defect protection for D1-D6, so explicit transition-authority contracts add little or no measurable protection.

If H0 is supported, `PUB-ME` must be narrowed or absorbed into the doctoral synthesis rather than preserving a weak standalone novelty claim.

## 4. Comparator hierarchy

The candidate method must not be compared against a straw man.

Each seeded defect is assessed against three oracle layers.

### B0 — successful-run reference regression

Includes:

- frozen reference outputs or trajectories at declared tolerances;
- successful completion;
- accepted endpoint/state comparison.

B0 corresponds to a common behavior-preserving modernization baseline, but is not treated as sufficient scientific-software practice.

### B1 — strong conventional scientific-software qualification

Includes all applicable established checks that do **not** require the explicit candidate-to-accepted authority contract being tested:

- B0 reference regression;
- mass/conservation and domain invariants;
- unit and integration tests;
- restart/split-run consistency where applicable;
- deterministic/reproducibility checks;
- existing process/numerical invariants;
- relevant metamorphic/property checks when an established relation exists;
- conventional CI failure handling.

B1 must be assembled from real SWAP/SWAP5 qualification practice and credible prior literature. Tests may not be omitted merely because they would detect a mutant.

### B2 — transition-authority qualification

B2 contains B1 plus direct or structural oracles for:

- committed-state immutability during rejected work;
- candidate origin/revision/interval identity;
- accepted-only accounting publication;
- accepted-only restart persistence;
- separation of numerical workspace from physical state;
- accepted-only external publication/observer effects.

The primary comparison is `B1 versus B2`, not `B0 versus B2`.

## 5. Experimental unit

The primary unit is a **preregistered semantic defect family instantiated on a bounded transaction-capable Reference route**.

A defect is not counted as detected merely because the injected harness refuses to compile. Each mutant must execute far enough to exercise the intended semantic fault unless the production interface structurally prevents construction of the invalid operation. Structural prevention must be demonstrated through the public/admitted API, not inferred from documentation.

No fault-injection mutant may be merged into production or become scientific authority.

## 6. Defect families

### D1 — rejected candidate mutates committed physical state

Defect semantics:

- a physical trial starts from accepted state `S_n`;
- candidate work modifies a value that is also reachable from committed state;
- the trial is rejected;
- the committed physical state is no longer bitwise/semantically identical to `S_n`.

Primary seeded mutation:

- introduce one deliberate alias/write-through path from candidate physical state into the committed-state object in a qualification-only harness or test-only faulty adapter;
- force rejection **after real physical solver execution**, not during preflight.

Primary scientific outcomes:

- committed-state digest before versus after rejection;
- next accepted endpoint versus clean control;
- integrated balance divergence after continuation.

Expected B2 oracle:

- immediate committed-state immutability failure at rejection boundary.

### D2 — retry double-counts scientific exchange/accounting

Defect semantics:

- a rejected attempt contributes one or more flux/storage-transfer quantities to accepted accounting;
- a later retry succeeds;
- the successful contribution is added again.

Primary seeded mutation:

- in qualification-only instrumentation, move one accepted-ledger update from post-acceptance publication into candidate/trial evaluation while retaining the normal post-accept update.

Primary scientific outcomes:

- cumulative accepted inflow/outflow/storage ledger;
- mass closure;
- endpoint state;
- whether endpoint state can remain plausible despite ledger corruption.

Expected B2 oracle:

- accepted ledger unchanged after rejected attempt; exactly one publication after acceptance.

### D3 — wrong-origin candidate is accepted

Defect semantics:

- a candidate is produced from stale revision, wrong interval, or incompatible accepted origin;
- that candidate is committed to the current accepted lineage.

Primary seeded mutation:

- construct a candidate from valid accepted origin `A`;
- advance/replace accepted origin to `B` or alter the authoritative interval;
- attempt to commit candidate `A` as successor of `B` using only the tested contract surface;
- if the admitted API structurally rejects this, classify D3 as prevented-by-contract rather than injecting an internal bypass.

Primary scientific outcomes:

- commit status;
- revision/lineage identity;
- endpoint state if an intentionally bypassed diagnostic variant is later required.

Expected B2 oracle:

- fail-closed origin/revision/interval mismatch before accepted state mutation.

### D4 — restart captures speculative state

Defect semantics:

- a checkpoint/restart artifact is produced from candidate state after physical execution but before final acceptance;
- the originating trial is rejected;
- restart continues from a state that never became scientifically accepted.

Primary seeded mutation:

- qualification-only persistence hook snapshots candidate rather than committed state at the pre-accept boundary;
- trial is then rejected;
- simulation is restarted from the faulty artifact.

Primary scientific outcomes:

- restart artifact state digest versus accepted-state digest;
- continuous versus restarted trajectory;
- cumulative accounting after restart;
- lineage/revision mismatch.

Expected B2 oracle:

- persistence service refuses candidate/nonaccepted identity or direct accepted-state-only snapshot comparison fails before restart publication.

### D5 — numerical workspace becomes physical authority

Defect semantics:

- disposable numerical state such as Newton scratch, warm-start values, cached iterate or solver workspace survives rejection and is subsequently interpreted as accepted physical state rather than merely a numerical initial guess.

Primary seeded mutation:

- select one real Reference-solver workspace/warm-start quantity with no intended physical authority;
- qualification-only mutant copies it into a physical start-state field on retry or restore;
- do not change the physical equations or forcing.

Primary scientific outcomes:

- physical start state of retry;
- accepted endpoint;
- iteration count as secondary diagnostic only;
- mass/storage trajectory.

Expected B2 oracle:

- explicit physical-state identity remains derived from committed state while workspace may vary independently.

### D6 — rejected-trial external side effect survives

Defect semantics:

- a diagnostic, event, external exchange record, observer notification or other publication is emitted during candidate work;
- the candidate is later rejected;
- the side effect remains visible as if it were accepted model history.

Primary seeded mutation:

- choose one existing observable publication surface that is downstream-relevant but not needed to compute the candidate itself;
- emit it before acceptance in a qualification-only faulty route;
- force rejection after emission.

Primary scientific outcomes:

- external publication/event count;
- accepted revision/interval associated with publication;
- downstream observer record;
- physical state may remain unchanged, making this an important non-state contamination control.

Expected B2 oracle:

- no accepted/external publication before commit; rejected work produces zero accepted observer effects.

## 7. Clean controls

Every defect family must have a matched clean control with identical:

- model source except for the qualification-only mutation;
- physical parameters;
- forcing;
- accepted starting state;
- interval;
- solver and numerical policy except where the defect itself targets policy/state identity;
- compiler/optimization configuration.

The clean control must pass B0, B1 and B2.

Any B2 false positive on a clean control is a primary negative result.

## 8. Execution contexts

The primary semantic defect question is about transaction lifecycle, not broad hydrologic parameter coverage. Nevertheless a single synthetic state must not be allowed to determine the conclusion.

Use three bounded contexts where supported by the admitted Reference route:

### C-A — nonlinear/retry-sensitive profile

A case that produces genuine physical solver work and a controlled rejected/retried attempt.

### C-B — post-solver temporal rejection

A case where physical solver execution succeeds but the outer temporal/acceptance policy rejects the candidate, directly exercising the boundary already demonstrated by P1E02-style evidence.

### C-C — ordinary accepted control trajectory

A matched regime without rejection, used to demonstrate that the seeded defect is conditional on the transition boundary rather than causing generic corruption.

For D4 include a restart after the rejection point. For D6 include the selected external observer/publication surface.

If an intended context cannot be produced without changing production physics, document the blocker and do not silently replace it with an easier case after results are known.

## 9. Physical-regime replication

Where the same defect operator is physically meaningful, run it in at least two materially different Reference regimes, provisionally:

- drier/infiltration-oriented profile;
- wetter/drainage-oriented profile.

A third groundwater-sensitive regime may be added only if it is already inside the selected Reference capability envelope before execution.

These are robustness replications, not statistically independent defect families.

## 10. Outcome recording per run

Record before reading comparative conclusions:

```yaml
defect_family: D1..D6
mutant_id:
context:
physical_regime:
source_head:
clean_control_head:
forcing_identity:
accepted_origin_digest:
interval:
rejection_reason:
solver_executed: true|false

oracles:
  B0:
    detected: true|false
    first_failure:
  B1:
    detected: true|false
    first_failure:
  B2:
    detected: true|false
    first_failure:
    structurally_prevented: true|false

scientific_consequence:
  committed_state_changed_after_reject: true|false
  accepted_endpoint_difference:
  integrated_mass_difference:
  restart_difference:
  external_publication_difference:
  lineage_revision_difference:

detection_timing:
  before_contamination:
  at_acceptance_boundary:
  downstream_only:
  not_detected:

notes:
```

## 11. Primary analysis

The central artifact is a defect-by-oracle matrix, not a single aggregate mutation score.

For each D1-D6 report:

1. whether the defect is constructible through the admitted production interface;
2. whether B1 detects it;
3. whether B2 detects or structurally prevents it;
4. when detection occurs relative to contamination of accepted scientific history;
5. the scientific consequence if the fault is allowed to propagate;
6. whether the clean control produces any false positive.

### Primary result classes

- `NO_INCREMENTAL_VALUE`: B1 already detects/prevents the defect at an equally protective boundary.
- `EARLIER_DETECTION`: B1 eventually detects downstream divergence, but B2 detects before accepted history contamination.
- `UNIQUE_DETECTION`: B1 does not detect within the bounded experiment and B2 does.
- `STRUCTURAL_PREVENTION`: the admitted transition contract makes the invalid state transition unrepresentable without bypassing the production interface.
- `INCONCLUSIVE`: fault injection or comparator cannot be made scientifically fair.

No `EARLIER_DETECTION`, `UNIQUE_DETECTION` or `STRUCTURAL_PREVENTION` class may be assigned from architecture inspection alone.

## 12. Predeclared interpretation thresholds

The study does not claim population-level statistical inference from six semantic families.

Interpretation is case-based and comparative.

### Strong support for H-ME-TA

At least two materially different defect families show reproducible `EARLIER_DETECTION`, `UNIQUE_DETECTION` or `STRUCTURAL_PREVENTION`, with a demonstrated scientific/history consequence and no matched-control false positive, while the comparator includes the full B1 baseline.

### Limited support

Exactly one defect family shows clear incremental value, or incremental value is only demonstrated in one narrow execution context.

### No support / redirect paper

No defect family shows material incremental protection beyond B1, or the claimed distinction depends on weakening the B1 comparator.

These thresholds are pragmatic manuscript go/no-go criteria, not universal scientific laws.

## 13. Secondary analysis: cost

Only after detection results are frozen, measure incremental qualification cost of B2 relative to B1:

- wall-clock gate time;
- number of extra executable assertions/oracles;
- state/evidence data retained;
- implementation/test LOC only as descriptive context, not quality metric.

Do not trade defect coverage for runtime in the primary analysis.

## 14. Secondary RQ1b is gated by RQ1a

Do not begin a publication-primary change-aware requalification experiment until D1-D6 has at least `LIMITED_SUPPORT`.

If that gate is passed, a separately preregistered RQ1b experiment may compare:

1. blanket requalification;
2. generic code/test dependency impact selection;
3. scientific-semantic dependency selection using transition/state authority.

Required outcomes would include replay surface, execution cost, false-positive replay burden and false-negative omission against seeded/known impacts.

This experiment is deliberately deferred so that PUB-ME cannot rescue a failed state-authority hypothesis by shifting emphasis post hoc to governance.

## 15. Mutation implementation rules

- mutations are qualification-only and must never be merged into production;
- one primary semantic change per mutant;
- exact mutant diff frozen before execution;
- no post-result mutation redesign to improve B2 advantage;
- if a mutant is equivalent/non-operative, classify it and create a replacement only under a new preregistered mutant id with the reason preserved;
- production physics, boundary conditions and constitutive equations may not be altered merely to force a detectable consequence;
- compiler/optimization settings must be recorded;
- O0/O2 or other existing determinism gates remain applicable where relevant.

## 16. Blinding / chronology discipline

Practical full blinding is not possible because the architecture is known. The following chronology safeguards are mandatory:

1. this matrix is committed before implementation of the D1-D6 publication mutants;
2. exact primary mutant diff for each D family is committed before its result is inspected;
3. comparator membership B0/B1/B2 is frozen before running the mutant;
4. clean-control result is obtained alongside the mutant;
5. failed or null experiments remain in the register;
6. later redesigns use new ids and retain the old result.

## 17. Primary manuscript artifacts if the hypothesis survives

- `PUB-ME-F01`: transition-authority lifecycle and oracle layers, explanatory only;
- `PUB-ME-F02`: D1-D6 defect-by-oracle detection/prevention matrix, primary result;
- `PUB-ME-F03`: representative scientific consequence trajectories for selected supported defects;
- `PUB-ME-T01`: exact mutant, context, comparator and result registry;
- optional `PUB-ME-F04`: incremental qualification cost, secondary result.

The older broad migration-slice preservation material remains necessary context/evidence but is no longer sufficient to carry the primary novelty claim.

## 18. Hard publication firewall

This experiment does not claim:

- a new numerical time integration method;
- invention of rollback or transactional simulation;
- superiority of RossFast or any alternative solver;
- groundwater-coupling accuracy;
- MODFLOW coupling novelty;
- general proof for all scientific software;
- that every defect in D1-D6 has occurred historically in SWAP;
- that governance metadata is itself a scientific contribution.

RossFast and groundwater coupling may later demonstrate that the preserved denominator remains usable, but their scientific results remain owned by `PUB-SQ` and `PUB-GC`.

## 19. Go/no-go decision

A standalone `PUB-ME` method paper remains protected only if D1-D6 demonstrates nontrivial incremental value beyond B1 and the literature search still finds no close equivalent before manuscript submission.

Otherwise:

- retain the modernization evidence as rigorous research infrastructure;
- use it in the PhD synthesis and as methodological context for later papers;
- do not manufacture a standalone novelty claim from architecture quality alone.
