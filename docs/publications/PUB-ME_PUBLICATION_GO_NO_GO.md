# PUB-ME standalone publication go/no-go after D1-D6

Status: **PROVISIONAL_GO_NARROWED**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Decision date: 2026-09-18

Canonical evidence authority:

`integration/f-ci-canonical@d517088cdc1cd82904b37648d6556dc79d57a641`

## 1. Decision

**Verdict: `PROVISIONAL_GO_NARROWED`**

A standalone PUB-ME paper remains scientifically defensible enough to continue.

The paper is **not yet manuscript-claim-ready** and **not submission-ready**.

The original broad modernization paper is rejected.

The surviving paper must be centered on one narrow empirical question:

> During staged modernization of a mature time-stepped process model, do explicit transition-authority contracts at the candidate-to-accepted state boundary provide incremental protection against scientifically consequential contamination faults beyond a strong baseline of established scientific-software testing?

## 2. Why this is a provisional GO

The preregistered primary experiment set is complete and does not collapse to one repeated mechanism.

Conservatively grouped, D1-D6 exercise at least five authority surfaces:

1. committed physical-state ownership / candidate-origin commit authority;
2. accepted scientific accounting;
3. accepted restart/persistence;
4. numerical workspace versus physical retry origin;
5. external accepted publication.

Observed outcomes:

- structural prevention on committed-state / candidate-origin authority;
- earlier fail-closed localization on accounting, persistence, numerical retry origin and external publication;
- matched clean controls;
- no result-dependent weakening of B1;
- no production/reference mutant admitted;
- no `UNIQUE_DETECTION` claim.

The experiments therefore support the narrow proposition that explicit transition authority can stop or localize invalid scientific history before the next authoritative lifecycle stage.

## 3. Why this is not yet a full GO

### 3.1 No UNIQUE_DETECTION result

For D2, D4, D5 and D6, strong B1 eventually detects the seeded fault.

The incremental effect is earlier localization, not exclusive coverage.

The manuscript must therefore demonstrate why the timing boundary is scientifically consequential:

- before accepted-history accounting is extended;
- before speculative state is persisted/restored;
- before another physical solve is run;
- before an external accepted publication is emitted.

### 3.2 Structural prevention can look like ordinary good software design

D1/D3 are valuable but vulnerable to an “obvious engineering” reviewer response.

Their role should be to establish the authority model, not carry the paper alone.

### 3.3 Qualification-only mutants

The fault operators are deliberately seeded.

They show mechanism vulnerability/protection, not prevalence of existing SWAP defects.

### 3.4 One-system evidence

The empirical case is SWAP5.

Transferability must be presented as a proposed pattern, not universal proof.

## 4. Protected primary contribution

The primary contribution should now be stated as:

> An empirically evaluated transition-authority method for staged modernization of stateful scientific simulators, in which computed candidate state is distinguished from accepted scientific history and authority is enforced before state, accounting, persistence, numerical continuation or external publication can advance.

The empirical result is:

> Across preregistered contamination families in the SWAP modernization case, explicit authority contracts either structurally prevent invalid transitions or detect them before the invalid computation propagates into the next authoritative lifecycle stage. Strong conventional qualification still detects the executable mutants later; the contribution is therefore authority-boundary prevention/localization, not unique fault detection.

## 5. Claims removed from the paper

Do not protect any of the following as novelty:

- model modernization;
- refactoring while preserving outputs;
- modularity;
- modern Fortran/data structures;
- transactional simulation;
- rollback/retry;
- checkpoint/restore;
- accepted/rejected numerical timesteps;
- CI/continuous verification;
- regression, mutation or metamorphic testing;
- fault injection;
- provenance;
- generic change-impact analysis;
- evolving assurance evidence.

These are context/prior art only.

## 6. Mandatory evidence gates before manuscript claim freeze

### G1 — D2 physical-regime replication

Status: **OPEN / mandatory**

Reason:

D2 is the clearest accounting example where:

- accepted endpoint is unchanged;
- canonical accepted accounting is unchanged;
- net mass closure can remain green;
- an external accepted-history ledger is nevertheless wrong.

Its result record explicitly requires physical-regime replication.

Required outcome:

At least one prospectively selected additional regime must reproduce the meaningful B1/B2 timing distinction without post-result tuning.

A negative replication is valid evidence and must narrow the D2 claim.

### G2 — preservation denominator

Status: **OPEN / mandatory**

The paper cannot be only a fault-injection architecture study.

It must show that the modernized architecture preserves the declared scientific denominator across a small, representative set of migration slices / hydrologic regimes.

The minimum denominator should include:

- state trajectory preservation;
- integrated water/accounting preservation;
- accepted temporal evolution;
- restart/continuation where relevant.

Do not narrate every migration workunit.

### G3 — literature novelty closure

Status: **OPEN / mandatory**

Pass 5 found no close equivalent to the exact combined claim, but this is not priority proof.

Before submission:

- complete citation chasing around the closest modernization papers;
- update recent 2026 scientific-software modernization/fault-injection work;
- close the review date explicitly;
- use bounded novelty wording.

### G4 — realistic end-to-end illustration

Status: **recommended, close to mandatory**

Show the accepted/candidate/publication lifecycle in one realistic SWAP execution without injecting a fault.

Purpose:

demonstrate that the authority surfaces studied by D1-D6 correspond to real full-model lifecycle boundaries rather than only synthetic harness constructs.

This is not another positive defect result.

## 7. RQ1b selective requalification decision

Original gate:

RQ1b may start only if the primary transition-authority hypothesis survives D1-D6.

That gate is technically satisfied.

However:

**Decision: DEFER_PUBLICATION_PRIMARY_RQ1B**

Do not start a large selective-requalification experiment as a second primary novelty line yet.

Reasons:

- generic change-impact/evolving-assurance prior art is strong;
- the transition-authority story is now much sharper;
- adding RQ1b risks turning the manuscript back into a broad governance paper;
- G1-G3 have higher scientific priority.

RQ1b remains available for:
- a bounded secondary analysis;
- thesis synthesis;
- or a separate later methods question if it develops its own clear novelty.

## 8. Recommended manuscript architecture

### 1. Introduction

Problem:
mature process models must evolve while their implementation partly defines scientific meaning.

Prior art:
modernization, modularization, reproducibility, testing, rollback and change impact are established.

Gap:
during architectural replacement, computed state and accepted scientific history are not the same thing; the empirical value of explicitly governing that transition in model modernization remains insufficiently demonstrated.

RQ:
the narrowed transition-authority question.

### 2. Case and scientific denominator

- SWAP 4.3.1 → SWAP5;
- only enough architecture/history to define the scientific denominator;
- no chronological repository narrative.

### 3. Transition-authority method

Minimal generic lifecycle:

`accepted state -> candidate execution -> assessment -> accept/commit or reject/discard`

Authority objects:

- physical state;
- accounting;
- persistence;
- numerical continuation;
- external publication.

### 4. Strong comparator and preregistration

- B0 only as context;
- B1 as real comparator;
- B2 transition-authority layer;
- D1-D6 preregistration;
- negative/blocked work retained.

### 5. Preservation denominator results

G2.

### 6. Transition-authority experiments

Group by mechanism, not D-number chronology:

- structural state/origin authority: D1+D3;
- accounting: D2;
- persistence: D4;
- numerical state: D5;
- external publication: D6.

### 7. Cross-defect synthesis

Primary figure/table:

- authority object;
- contamination channel;
- B1 detection point;
- B2/prevention point;
- scientific consequence;
- result class.

### 8. Discussion

- earlier detection versus unique detection;
- seeded mutants;
- generalizability limits;
- relationship to numerical rollback, scientific testing and modernization literature;
- cost/complexity;
- relevance to later solver/coupling work.

### 9. Conclusions

Bounded result only.

## 9. Candidate title

Preferred working title:

**Protecting accepted scientific history during model modernization: transition-authority experiments in a mature process-based simulator**

Alternative:

**From computed state to accepted scientific history: qualifying transition authority during scientific model modernization**

Avoid titles centered only on “SWAP5 architecture” or “evidence-preserving refactoring”.

## 10. Candidate primary figures

1. accepted/candidate scientific-authority lifecycle;
2. small preservation-denominator figure;
3. D1-D6 cross-defect authority matrix;
4. detection/prevention timing schematic for representative D2/D4/D6 cases;
5. optional SWAP migration context figure.

Avoid six nearly identical defect figures.

## 11. Publication threshold after remaining gates

### Upgrade to `GO_MANUSCRIPT_CLAIM_FREEZE` if:

- G1 closes with interpretable replication evidence;
- G2 demonstrates credible scientific-denominator preservation;
- G3 finds no close equivalent that collapses the narrowed contribution;
- cross-defect claims remain unchanged after those results.

### Downgrade to `NO_GO_STANDALONE` if:

- preservation denominator cannot be demonstrated;
- the narrowed claim collapses to generic precondition/assertion engineering with no defensible scientific consequence;
- close prior work is found that already demonstrates the same combined empirical method;
- replication reveals that the key timing distinction is fixture-specific and not transferable enough to support the case-study claim.

### Narrow further if:

- only specific authority surfaces replicate;
- the strongest result becomes one or two exemplar mechanisms rather than a general transition-authority pattern.

## 12. Current decision summary

Scientific hypothesis:

`SUPPORTED_WITH_LIMITATIONS`

Standalone paper:

`PROVISIONAL_GO_NARROWED`

Manuscript claim freeze:

`NOT_YET`

Submission readiness:

`NO`

Next primary action:

`G1 — preregister and execute D2 physical-regime replication`

Parallel non-experimental action:

`G2 — reconcile the minimum preservation-denominator evidence already available`

Do not start publication-primary RQ1b before G1-G3.
