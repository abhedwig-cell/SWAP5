# PUB-ME research-question adjudication

Status: **working scientific decision surface, not manuscript claim**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Adjudication date: 2026-09-18

## 1. Question under review

Current contract question:

> How can a mature process-based scientific model be structurally transformed while preserving defined scientific behaviour, provenance and qualification evidence?

## 2. Decision

**Verdict: TOO_BROAD_FOR_PRIMARY_NOVELTY_CLAIM**

The question remains useful as an overarching design problem, but the literature review shows that it is not sufficiently discriminating for a paper-level research question.

Prior work already establishes substantial parts of the answer:

- behavior-preserving refactoring;
- longitudinal scientific software evolution;
- physics-preserving modernization of hydrologic and Earth-system models;
- continuous/ongoing verification of evolving numerical models;
- simulation transactions, speculative state and rollback;
- standards for model state save/restore and interoperability;
- regression, metamorphic and adversarial testing of scientific software;
- claim-evidence traceability, evidence reuse and change-impact analysis in evolving assurance cases;
- scientific workflow provenance and workflow evolution.

A manuscript centered on the current broad question risks being judged as a well-engineered application of existing ideas.

## 3. Surviving scientific problem

The remaining problem is not whether a legacy model can be modernized safely in principle.

The more specific question is whether combining:

- explicit authority over accepted versus speculative scientific state; and
- scientific-semantic dependencies between claims and qualification evidence

provides **observable protection beyond output-regression-centered modernization** during staged evolution of a mature time-stepped process model.

This distinction matters because the individual mechanisms are prior art; their integrated scientific value is not yet established by the literature reviewed so far.

## 4. Recommended primary research question

> **Can explicit accepted-state authority and scientific claim-evidence dependencies detect or prevent semantic failures that output-regression-centered modernization does not, while preserving a bounded qualification burden during staged evolution of a mature time-stepped process model?**

This question is preferred because it is comparative, falsifiable and measurable.

## 5. Operational hypotheses

### H-ME1 Preservation

Selected architectural migration slices preserve the declared SWAP scientific denominator over state trajectories, integrated accounting, restart semantics and accepted temporal evolution.

Failure of this hypothesis means the modernization method does not preserve its own declared baseline.

### H-ME2 Added protection

There exist plausible state-transition defects for which successful-run output regression alone is insufficient, while explicit accepted/candidate/workspace authority either prevents the defect or exposes it through a direct invariant failure.

Failure condition:

- no meaningful defect family demonstrates added protection beyond conventional regression/invariant practice.

### H-ME3 Scientific change-impact value

Scientific claim/evidence dependencies can select which qualification evidence must be replayed or invalidated after a change with less unnecessary replay than blanket requalification and without lower detection of scientifically relevant seeded impacts.

Failure condition:

- the scheme reduces to ordinary code/test dependency selection;
- it misses scientifically relevant seeded impacts;
- or the selection remains so broad that no practical distinction from blanket qualification exists.

### H-ME4 Denominator stability

Later solver substitution and external coupling can be qualified against the same accepted scientific-state denominator without silently redefining the preserved reference semantics.

This is an enabling hypothesis only. It does not transfer solver/coupling scientific claims into PUB-ME.

## 6. Required baseline comparator

The primary comparator should be a credible **output-regression-centered modernization** approach, not an intentionally weak straw man.

Minimum comparator characteristics:

- same legacy reference cases;
- successful execution required;
- output/state comparisons against a frozen baseline at declared tolerances;
- conventional regression CI;
- no explicit transaction-level accepted/candidate scientific-state authority;
- no scientific claim/evidence change-impact layer beyond ordinary test/code ownership.

Comparator design must be grounded in practices actually used in prior hydrological/Earth-system modernization literature.

## 7. Primary outcomes

The paper should avoid subjective claims such as `safer`, `more trustworthy` or `better governed` unless tied to measurable outcomes.

Candidate measurable outcomes:

- preservation error over selected scientific trajectories;
- mass/accounting residuals;
- restart/split-run divergence;
- number and class of seeded semantic defects detected by each approach;
- false negatives in defect detection;
- qualification evidence selected for replay after each change;
- replay runtime/cost;
- false-positive requalification burden;
- false-negative evidence reuse;
- number of later extensions requiring a change to the original preservation denominator.

## 8. Strongest expected figure/table set

### Figure 1 — scientific authority model

A minimal accepted-state/candidate/evidence dependency diagram. This is explanatory, not itself a result.

### Figure 2 — preservation results across migration slices

Scientific trajectories/balances/restart equivalence against the frozen denominator.

### Figure 3 — defect-detection comparison

Matrix of seeded/plausible defect classes versus:

- ordinary output regression;
- generic invariant/regression checks;
- explicit state-authority checks.

This is likely the central result figure if H-ME2 is supported.

### Figure 4 — qualification-impact comparison

For representative code changes, compare:

- full replay;
- code-dependency-based regression selection;
- scientific claim/evidence selection.

Report cost and fault-detection coverage.

### Table 1 — prior-art boundary

For each adjacent literature family, state what is established and therefore explicitly **not** claimed as novel.

### Table 2 — migration slices and semantic risks

Legacy ownership, architectural change, scientific risk, evidence, outcome.

## 9. Manuscript claim discipline

Allowed candidate wording if supported by experiments:

> In this case study, explicit accepted-state authority and scientific claim/evidence dependencies exposed classes of migration error and constrained requalification in ways not provided by output regression alone.

Avoid:

- first transactional scientific model;
- first rollback-safe simulation architecture;
- first behavior-preserving scientific refactor;
- first continuous verification method;
- first evidence-aware software evolution approach;
- universally trustworthy modernization;
- proof that the method generalizes to all scientific models.

## 10. Generalization boundary

A single SWAP case can support:

- a deeply evidenced case-study result;
- a proposed transferable pattern for similar deterministic, stateful, time-stepped process models;
- hypotheses for broader scientific-software classes.

It cannot by itself establish universal superiority across:

- chaotic climate models;
- agent-based stochastic models;
- event-driven simulations;
- data-driven ML models;
- all multiphysics frameworks.

Any generalization beyond the demonstrated class must remain explicitly provisional.

## 11. Journal implication

This narrower RQ improves fit with a methods-oriented journal because the paper would evaluate a general scientific-software method rather than document a new SWAP release.

However, journal selection should remain conditional on results:

- strong comparative empirical results and transferable method: Environmental Modelling & Software remains plausible;
- primarily model-specific modernization and qualification case study: Geoscientific Model Development is safer;
- primarily software-engineering evidence/change-impact contribution with limited hydrological result: a scientific-software or software-engineering venue may become more appropriate.

No journal priority claim is made here.

## 12. Decision gate before manuscript drafting

Do not start a full manuscript around PUB-ME until all four conditions are met:

1. targeted literature pass on physical-invariant/semantic regression and scientific change-impact finds no close equivalent;
2. E-ME2 has a preregistered defect matrix capable of distinguishing the proposed method from ordinary regression;
3. E-ME3 has a credible code-dependency baseline and measurable scientific-evidence selection outcome;
4. at least a pilot subset demonstrates that the new RQ produces nontrivial empirical results.

Until then, PUB-ME remains a viable research hypothesis, not an admitted publication claim.