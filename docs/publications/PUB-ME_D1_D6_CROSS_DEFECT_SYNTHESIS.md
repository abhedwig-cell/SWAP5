# PUB-ME D1-D6 cross-defect synthesis

Status: **PRIMARY_EXPERIMENT_SET_COMPLETE__CROSS_DEFECT_ADJUDICATION**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Canonical evidence authority:

`integration/f-ci-canonical@d517088cdc1cd82904b37648d6556dc79d57a641`

## 1. Purpose

This synthesis determines whether the six preregistered transition-authority defect families provide materially independent evidence for the narrowed PUB-ME research question.

The six labels are not treated as six independent successes.

Primary question:

> During staged modernization of a mature time-stepped process model, do explicit transition-authority contracts at the candidate-to-accepted state boundary provide incremental protection against scientifically consequential contamination faults beyond a strong baseline of established scientific-software testing?

## 2. Cross-defect matrix

| Defect | Protected authority | Seeded contamination channel | B1 first detection | B2 / structural boundary | Result | Mechanism class |
| --- | --- | --- | --- | --- | --- | --- |
| D1 | committed physical storage | candidate/public snapshot writes through to authoritative physical state | not instantiated as executable admitted write-through; public mutation remains on detached clone | private committed storage + clone-only public extraction makes direct write-through unconstructable | `STRUCTURAL_PREVENTION` | A — state ownership / alias isolation |
| D2 | accepted scientific accounting | rejected trial contributes to an external accepted ledger and is counted again after successful retry | after acceptance, accepted-total regression against canonical accepted transfer | accepted ledger must still be empty at retry/re-execution entry | `EARLIER_DETECTION` | B — accepted accounting publication |
| D3 | accepted trajectory origin | candidate from wrong lineage, stale revision or wrong accepted time is committed | no invalid commit occurs; downstream B1 consequence is prevented | public commit seam rejects invalid origin before authoritative mutation | `STRUCTURAL_PREVENTION` | A — commit/provenance authority |
| D4 | persistent accepted continuation | restart artifact contains speculative candidate physical state under accepted provenance | after faulty artifact reconstruction/restore, restart round-trip comparison | physical persistence payload must match current accepted physical state before publication | `EARLIER_DETECTION` | C — persistence / restart authority |
| D5 | physical retry origin | numerical Newton workspace is promoted to physical state for retry | after retry solve, endpoint/storage regression | retry physical origin must derive from committed physical state, not solver scratch | `EARLIER_DETECTION` | D — numerical workspace / physical-state authority |
| D6 | external accepted publication | rejected/non-authoritative computation emits immutable external accepted result | after rejected operation, accepted-output regression sees unexpected publication | outer transaction must be accepted with exactly one commit before observer emission | `EARLIER_DETECTION` | E — external publication authority |

## 3. Independence adjudication

### Class A — state and commit authority: D1 + D3

D1 and D3 must not be counted as two fully independent empirical detection results.

Common denominator:

- both protect the authoritative committed trajectory before mutation;
- both rely on explicit ownership/provenance at the commit-state boundary;
- both classify as structural prevention rather than detection timing.

Material distinction:

- D1 addresses aliasability/ownership of the physical state carrier itself;
- D3 addresses causal origin identity of a candidate that is otherwise a valid materialized state.

Publication treatment:

- present them together as one **structural authority family** with two submechanisms;
- do not use them to claim two independent replications of H-ME-TA.

### Class B — accepted accounting publication: D2

D2 is materially distinct from Class A.

The authoritative physical endpoint and canonical accepted accounting remain unchanged, while a qualification-only external accepted ledger is contaminated.

The important result is not that B1 fails. Strong B1 detects the mismatch after acceptance.

The incremental B2 result is that accepted-history contamination is identifiable at retry entry before a subsequent accepted computation is allowed to legitimize the history.

D2 is the strongest direct evidence that endpoint correctness and even net mass closure can coexist with corrupted accepted-history accounting.

### Class C — persistence/restart authority: D4

D4 is materially distinct from D2.

The contaminated artifact is not an accounting ledger but a continuation state that can become the origin of a later simulation.

Strong B1 detects the round-trip mismatch after restore.

B2 detects before persistence publication.

The continuation experiment demonstrates a scientific consequence: the faulty restart shifts the subsequent trajectory by one speculative state step while the local mass invariant can remain green.

### Class D — numerical workspace versus physical state: D5

D5 is materially distinct from D1-D4.

The fault does not alter committed state or a persistent artifact directly. It promotes disposable nonlinear-solver scratch into the physical origin of a new solve.

B2 identifies the wrong authority before the retry.

B1 detects after another physical solve through endpoint and storage divergence.

The incremental value is therefore localization and prevention of propagation into additional scientific computation, not unique fault coverage.

### Class E — external accepted publication: D6

D6 is materially distinct from D2 and D4 because the protected object is an externally visible immutable publication rather than internal accounting or restart state.

The accepted physical state remains unchanged.

B2 detects before observer emission.

Strong B1 detects after the rejected operation because an external accepted-publication record exists when the accepted stream should contain none.

This is the clearest example where correct physical model state does not imply correct externally visible scientific history.

## 4. Independence conclusion

The six defect families reduce conservatively to **five authority mechanisms**, of which the first is represented by two related subcases:

A. committed physical-state ownership and candidate-origin commit authority — D1/D3;
B. accepted accounting publication — D2;
C. accepted restart/persistence — D4;
D. solver-workspace versus physical-state origin — D5;
E. external accepted publication — D6.

Even under the stricter grouping that treats D1 and D3 as one family, the experiment set contains multiple materially different scientific-history channels.

Therefore the preregistered minimum requirement of at least two materially distinct authority mechanisms with positive incremental protection is satisfied.

This conclusion does not imply statistical independence or population-level defect-detection rates.

## 5. Primary hypothesis adjudication

### H-ME-TA

> Explicit transition-authority contracts provide observable incremental protection against at least some scientifically consequential state-history contamination faults beyond a credible conventional scientific-software qualification baseline.

**Verdict: SUPPORTED_WITH_LIMITATIONS**

Support:

- structural prevention exists for the admitted committed-state / commit-origin boundary;
- four different non-structural channels show earlier detection at the authority boundary than a strong conventional B1 consequence check;
- clean controls remained valid;
- the seeded mutations are bounded and preregistered;
- no result required weakening B1 after observing the outcome.

Limitations:

- no primary defect family establishes `UNIQUE_DETECTION`;
- the strongest recurring incremental effect is timing/localization, not broader fault coverage;
- seeded faults are qualification-only and do not demonstrate existing SWAP5 production defects;
- most defect families have one principal fixture;
- the experiment set is a mechanism study, not an estimate of real-world defect prevalence or probability.

## 6. Scientific meaning of EARLIER_DETECTION

For this paper, `EARLIER_DETECTION` is scientifically relevant only when the boundary precedes a meaningful irreversible or propagating action.

That condition is met differently across D2-D6:

- D2: before contaminated accounting can enter the accepted retry history;
- D4: before speculative physical state is persisted/restored as continuation authority;
- D5: before another numerical/physical solve is executed from a non-authoritative origin;
- D6: before an external accepted-history side effect is emitted.

The manuscript must not reduce this to a generic claim that earlier test failure is always better.

The relevant property is:

> invalid scientific authority is identified before the invalid state/artifact/side effect is allowed to participate in the next authoritative lifecycle stage.

## 7. Strongest manuscript results

### Primary result family 1 — structural scientific authority

D1/D3 together show that explicit ownership and origin contracts can make certain invalid scientific transitions unrepresentable or fail-closed before authoritative mutation.

### Primary result family 2 — accepted-history contamination timing

D2/D4/D5/D6 show four distinct channels in which a strong B1 comparator eventually detects the seeded error, while the transition-authority oracle localizes the violation before propagation/publication.

### Particularly informative cases

D2:
- accepted physical endpoint unchanged;
- canonical accepted transaction accounting unchanged;
- equal erroneous inflow/outflow can leave net mass closure green;
- external accepted ledger is nevertheless wrong.

D4:
- local mass invariant can remain green;
- faulty restart changes subsequent scientific trajectory.

D6:
- accepted physical state remains unchanged;
- external accepted-history stream is nevertheless contaminated.

These cases demonstrate why “correct accepted endpoint” and “correct accepted scientific history” are not identical properties.

## 8. Results that must not be overstated

Do not claim:

- transition-authority testing finds faults that strong B1 can never find;
- B2 is universally superior to regression, mutation or invariant testing;
- all six defect families are independent;
- six successful experiments estimate a detection probability;
- the seeded faults existed in legacy SWAP or current SWAP5;
- the mechanisms themselves are novel;
- every stateful environmental model requires the exact SWAP5 architecture.

## 9. Remaining empirical gaps

### Mandatory G1 — D2 physical-regime replication

D2's result record explicitly leaves a replication obligation open.

At least one additional prospectively selected physical regime must show that the D2 operator and B1/B2 timing distinction remain meaningful without tuning the fault magnitude or acceptance criteria after observing results.

This is the most explicit unfinished primary-experiment obligation.

### Mandatory G2 — behavior-preservation denominator

The narrowed transition-authority result still sits inside a modernization paper.

The manuscript must demonstrate that the architectural migration preserved a scientifically meaningful denominator across representative migration slices, rather than testing authority semantics only on qualification harnesses.

The existing PUB-ME preservation work should be reduced to the minimum evidence needed for that denominator rather than becoming a second broad paper inside the paper.

### Mandatory G3 — novelty closure

The living literature review must be updated against the final narrowed empirical claim:

> explicit transition-authority contracts as an empirical modernization method for preventing/localizing contamination of accepted scientific history.

A close prior method can still narrow or defeat the standalone novelty claim.

### Recommended G4 — one realistic end-to-end illustration

A realistic SWAP trajectory should illustrate, without seeded production mutation, where the accepted/candidate/publication boundaries occur in a full model run.

This is contextual validation of relevance, not another defect-family success.

## 10. RQ1b gate

The primary transition-authority hypothesis is supported strongly enough that RQ1b is **methodologically permitted** by the original preregistration.

However, starting RQ1b as a second primary novelty line is **not recommended yet**.

Reason:

- change-impact analysis and evolving assurance evidence have strong prior art;
- adding a large selective-requalification study risks diluting the sharper transition-authority contribution;
- G1-G3 are more important to standalone PUB-ME viability.

RQ1b may later be used as a bounded secondary analysis if it adds empirical value without becoming the paper's rescue mechanism.

## 11. Cross-defect verdict

`PRIMARY_HYPOTHESIS_SUPPORTED_WITH_LIMITATIONS`

The D1-D6 experiment set provides coherent evidence that explicit scientific transition authority can add structural prevention or earlier fail-closed localization across multiple accepted-history channels.

The result is stronger than “refactoring plus tests” but narrower than “a generally superior testing method”.
