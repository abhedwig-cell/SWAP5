# PUB-ME cross-defect adjudication

Status: **POST-RESULT SCIENTIFIC ADJUDICATION**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Adjudication base: `integration/f-ci-canonical@d517088cdc1cd82904b37648d6556dc79d57a641`

## 1. Purpose

This document performs the cross-defect analysis required by the D1-D6 preregistration before any publication-primary work on selective requalification (RQ1b).

It is explicitly a **post-result synthesis**. The individual defect definitions, B0/B1/B2 hierarchy, permitted classifications and paper falsification rule were frozen earlier at:

- preregistration head `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`;
- D1-D6 design blob `61f7133f19cc900971aa454b7bdb16a254468eda`.

This synthesis does not treat six defect labels as six statistically independent experiments.

## 2. Result set

The admitted primary results are:

| Defect | Consequence channel | Classification | Increment over strong B1 |
| --- | --- | --- | --- |
| D1 | committed physical state | `STRUCTURAL_PREVENTION` | direct public write-through is unrepresentable; snapshots are detached |
| D2 | accepted accounting | `EARLIER_DETECTION` | B2 detects rejected-work accounting at retry entry; B1 catches final accepted-total mismatch later |
| D3 | lineage/revision/time provenance | `STRUCTURAL_PREVENTION` | invalid origin cannot pass the public commit contract |
| D4 | restart persistence | `EARLIER_DETECTION` | B2 detects candidate-derived restart before publication; B1 detects after restore |
| D5 | numerical workspace origin | `EARLIER_DETECTION` | B2 detects wrong physical retry origin before solve; B1 detects endpoint/storage divergence after solve |
| D6 | external accepted publication | `EARLIER_DETECTION` | B2 blocks before observer emission; B1 detects the external record after the rejected operation |

No D1-D6 primary result is classified as `UNIQUE_DETECTION`.

## 3. What the experiment actually supports

### 3.1 Structural prevention exists for two distinct authority boundaries

D1 and D3 establish different but related structural properties:

- D1 protects **where authoritative physical state can be mutated**;
- D3 protects **which candidate origin may become accepted state**.

Both are transaction/state-authority mechanisms. They should not be presented as independent statistical replications.

They do demonstrate that part of the proposed method is stronger than a post-hoc test: some invalid transitions are not representable through the admitted public interface.

### 3.2 Four executable fault families show earlier causal-boundary detection

D2, D4, D5 and D6 all produce `EARLIER_DETECTION`, but through materially different consequence channels:

- D2: scientific accounting;
- D4: persisted restart history;
- D5: numerical scratch promoted to physical origin;
- D6: externally visible accepted publication.

The common principle is intentional:

> non-authoritative computation must not cross the boundary into accepted scientific history or accepted side effects.

The experiments are therefore best interpreted as **cross-channel tests of one authority principle**, not as four independent estimates of an effect size.

### 3.3 Strong B1 remains effective

This is a central negative result.

For every executable D2/D4/D5/D6 mutant, the strong conventional B1 layer eventually detects the fault.

Therefore the data do **not** support claims such as:

- conventional scientific-software qualification cannot detect these faults;
- transition-authority testing has higher ultimate fault coverage in this experiment;
- B2 uniquely detects a class of errors missed by B1.

The measured incremental value is instead:

1. **structural prevention**, where the invalid transition cannot be constructed through the admitted interface; or
2. **earlier/localized detection at the causal authority boundary**, before invalid history, persistence, extra numerical work or external publication propagates.

### 3.4 Earlier detection is not equally consequential in every defect

The consequence of detection timing differs:

- D5 primarily prevents a scientifically invalid retry solve and subsequent trajectory propagation.
- D2 prevents rejected work from entering an accepted accounting carrier before accepted re-execution.
- D4 prevents publication/restoration of a state that never became accepted history.
- D6 is the strongest irreversibility example: B1 detects the fault only after the external observer has already received an accepted-labelled record.

The manuscript should not collapse these consequences into one scalar “safety improvement”.

## 4. Negative evidence retained

### D1-B

The planned continuation-timing extension was classified `BLOCKED_CONTINUATION_CONFIGURATION` because the frozen clean continuation did not accept. The configuration was not tuned after seeing the result.

### First D2 attempt

The first selected historical Reference retry authority was classified `BLOCKED_REFERENCE_RETRY_AUTHORITY` because its evolved dependency graph could not be reproduced directly. The experiment was stopped rather than repeatedly repairing the old harness until the desired transaction appeared.

### Parallel D6 PR #216

A later parallel D6 surface was closed after the earlier frozen D6 authority in PR #215 completed and was admitted. It is not used to strengthen the D6 result post hoc.

These records are part of the research evidence. They demonstrate chronology discipline, not additional support for H-ME-TA.

## 5. Preregistered threshold adjudication

The preregistered design required evidence of incremental protection in at least two materially different defect families, while allowing `EARLIER_DETECTION`, `UNIQUE_DETECTION` or `STRUCTURAL_PREVENTION` as positive bounded outcomes.

That minimum signal is met.

A conservative independence count does not need D1 and D3 to be treated as separate. D2, D5 and D6 alone cover three materially different channels using:

- real Reference accepted accounting/re-execution;
- real Reference numerical workspace/physical-state ownership;
- accepted external publication lifecycle.

D4 provides additional persistence/restart evidence but is not required to meet the minimum signal.

## 6. Revised answer to the primary research question

The frozen question asked whether explicit transition-authority contracts provide incremental protection beyond strong established scientific-software testing.

The evidence supports a **narrow qualified yes**:

> Within the preregistered SWAP5 defect classes, explicit transition-authority contracts either structurally prevent invalid candidate-to-accepted transitions or detect them at the causal boundary before strong conventional qualification detects their downstream consequence.

The evidence does **not** support:

> Transition-authority contracts detect more final faults than strong conventional scientific-software qualification.

That distinction must survive into the abstract, discussion and conclusion.

## 7. Recommended post-result research question

For the manuscript, a more evidence-aligned question is:

> **During staged modernization of a mature time-stepped process model, can explicit candidate-to-accepted transition authority prevent or localize contamination of scientific history at its causal boundary before downstream regression, conservation, restart or publication checks observe the consequence?**

A secondary question may now investigate whether the same scientific-semantic boundaries can reduce unnecessary requalification after later changes without losing relevant impact coverage.

The original preregistered question remains the experiment authority. This revised wording is a post-result manuscript framing and must be labelled as such.

## 8. Literature consequence

The final targeted search still finds extensive prior art for:

- accepted/rejected numerical steps;
- rollback and checkpoint/restart;
- behavior-preserving model modernization;
- regression, mutation and metamorphic testing;
- change-impact and assurance evidence.

Recent numerical work continues to treat a rejected step as one that leaves the accepted iterate unchanged and is recomputed or retried. That reinforces the non-novelty of rollback itself.

What remains provisionally distinctive is the **empirical modernization study** that treats candidate-to-accepted authority as a cross-cutting scientific-software boundary and tests its consequences across state, accounting, restart, workspace and publication channels.

This is still a bounded literature conclusion, not an international priority claim.

## 9. Generalization limits

The D1-D6 programme is one deep SWAP5 case study.

It does not estimate:

- real-world defect frequency;
- probability of failure reduction;
- development-effort savings;
- universal applicability to all scientific simulators.

The result is transferable as a candidate pattern, not statistically proven as a universal method.

## 10. Decision

**Cross-defect verdict: `PRIMARY_HYPOTHESIS_SUPPORTED_IN_BOUNDED_CLASSES`.**

**Publication verdict at this stage: `GO_NARROWED_CLAIM__NOT_MANUSCRIPT_READY`.**

The standalone PUB-ME line should continue, but only around the narrowed claim of structural prevention and causal-boundary localization.