# PUB-ME literature review pass 2

Status: **adversarial novelty review, second pass**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Review date: 2026-09-18

Base review authority: `PUB-ME_LITERATURE_REVIEW_PROTOCOL.md`

## 1. Purpose of this pass

The first pass left one candidate gap open: the combination of explicit accepted scientific state, speculative/rejected execution, staged modernization, and change-aware qualification evidence.

This second pass deliberately searched for prior work most capable of falsifying that combination. It focused on five high-risk areas:

1. long-running scientific model evolution with ongoing reproducibility checks;
2. transactional/speculative state semantics in simulation;
3. scientific-software testing beyond nominal regression;
4. change-aware evidence and assurance-case evolution;
5. provenance and workflow evolution.

The result is a **substantial narrowing** of the defensible PUB-ME contribution.

## 2. High-impact findings

### 2.1 Ongoing scientific reproducibility during software evolution is established prior art

Mahajan et al. (2019), *Ongoing solution reproducibility of earth system models as they progress toward exascale computing*, International Journal of High Performance Computing Applications 33(5), DOI 10.1177/1094342019837341.

What it establishes:

- an explicit methodology for checking solution reproducibility during ongoing E3SM software-infrastructure development;
- comparison against a verified model configuration in a development period with no intended science changes;
- a domain-appropriate equivalence criterion based on statistical climate distributions rather than bitwise equality;
- separation of infrastructure/compiler/library effects through controlled comparisons.

Novelty impact:

- removes any PUB-ME novelty claim that the scientific behavior of an evolving model should be continuously re-established during infrastructure change;
- removes novelty from defining preservation criteria that are scientifically appropriate rather than bitwise;
- strengthens the expectation that PUB-ME must compare against a clearly defined preservation baseline and not merely show successful regression tests.

What remains open relative to PUB-ME:

- the reviewed paper does not make accepted-versus-candidate state ownership or failed/retried timestep contamination the research object;
- it does not provide a claim/evidence dependency method for deciding which prior qualification artifacts remain authoritative after each architectural slice.

### 2.2 Longitudinal scientific-code evolution and software-process adaptation are established prior art

Dubey et al. (2014), *Evolution of FLASH, a multi-physics scientific simulation code for high-performance computing*, International Journal of High Performance Computing Applications 28(2), DOI 10.1177/1094342013505656.

Related software-process paper: Dubey et al. (2013), *The software development process of FLASH, a multiphysics simulation code*, IEEE SE-CSE workshop, DOI 10.1109/SECSE.2013.6615093.

What this work establishes:

- a long-lived scientific simulation code can undergo multiple major architectural revisions while remaining a production research platform;
- verification, maintainability, portability, user support, modularity and software-management policy evolve together;
- scientific research and software engineering can be mutually reinforcing rather than separate activities.

Novelty impact:

- removes novelty from the longitudinal aspect of scientific software evolution itself;
- removes novelty from arguing that scientific software needs an evolving software process during deep architectural change;
- weakens any paper structure based mainly on a chronology of successive SWAP5 architecture revisions.

What remains open:

- the reviewed FLASH work is not framed around explicit candidate/accepted scientific state and change-aware qualification authority.

### 2.3 Scientific-software evolution as a research topic is old, not new

Kelly (2009), *Determining factors that affect long-term evolution in scientific application software*, Journal of Systems and Software 82(5), 851-861, DOI 10.1016/j.jss.2008.11.846.

What it establishes:

- decades-long scientific software evolution is itself a studied software-engineering phenomenon;
- architecture and development-group characteristics materially influence successful long-term evolution;
- scientific software evolution deserves domain-specific study.

Novelty impact:

- PUB-ME cannot motivate itself by claiming scientific-software evolution has been neglected in general;
- the introduction should instead argue that a specific unresolved *scientific-semantic* problem remains within model modernization.

### 2.4 Generic behavior preservation is well established

AlOmar et al. (2021), *On preserving the behavior in software refactoring: A systematic mapping study*, Information and Software Technology 140, 106675, DOI 10.1016/j.infsof.2021.106675.

What it establishes:

- behavior preservation is foundational to refactoring;
- formal verification, language transformation, testing and dynamic analysis are established approaches;
- preconditions, postconditions and invariants are established mechanisms for checking refactoring correctness.

Novelty impact:

- PUB-ME cannot claim behavior-preserving transformation, invariants, or preservation pre/postconditions as novel concepts;
- any distinction must lie in the definition of scientific behavior and in the empirical consequences of its preservation boundary.

### 2.5 Transactional/speculative state semantics are established simulation concepts

Hoverd and Sampson (2010), *A Transactional Architecture for Simulation*, IEEE ICECCS, DOI 10.1109/ICECCS.2010.7.

Andelfinger and Uhrmacher (2024), *Synchronous speculative simulation of tightly coupled agents in continuous time on CPUs and GPUs*, SIMULATION, DOI 10.1177/00375497231158930.

Optimistic parallel discrete-event simulation literature also explicitly treats event executions as speculative/provisional, subject to rollback, and later committed once rollback is no longer possible.

What this cluster establishes:

- transactional simulation is not new;
- simulation state may be provisional and either committed or rolled back;
- rollback and state history are core execution concepts in speculative simulation.

Novelty impact:

- removes novelty from `candidate -> accept/reject -> commit/rollback` as an abstract execution pattern;
- removes novelty from the terms provisional, current, accepted, committed or transactional state themselves.

What remains open:

- applying such a boundary to preserve the scientific authority of an established deterministic process model during architectural replacement remains a distinct problem unless close prior work is found.

### 2.6 Save/restore, step acceptance and rollback are mature numerical/co-simulation capabilities

FMI specifications and co-simulation literature support saving/restoring complete model state and rollback. PETSc TS supports accepted/rejected timesteps and retry after rejected or failed stages.

Novelty impact:

- no claim is available around checkpoint/restore, timestep rejection, retry or rollback alone;
- SWAP5 must show a scientific-evolution consequence beyond these execution capabilities.

### 2.7 Adversarial testing of scientific software is established and expanding

Lin, Simon and Niu (2018/2020), *Exploratory Metamorphic Testing for Scientific Software*, Computing in Science & Engineering 22(2), DOI 10.1109/MCSE.2018.2880577.

Clark et al. (2023), *Testing Causality in Scientific Modelling Software*, ACM Transactions on Software Engineering and Methodology, DOI 10.1145/3607184.

Coleman et al. (2026), *Validating LLM-Modernized Scientific Software Through Differential Fault Injection*, arXiv:2608.14527. Preprint, not peer-reviewed at this review date.

What this cluster establishes:

- scientific software can be tested through properties and cross-run relations when conventional output oracles are insufficient;
- real scientific models have been subjected to metamorphic/causal testing;
- recent modernization research is explicitly moving beyond nominal equivalence to matched fault injection and off-nominal behavior.

Novelty impact:

- removes novelty from adversarial testing, fault injection, metamorphic testing or testing beyond successful nominal runs in isolation;
- PUB-ME adversarial experiments remain important evidence but cannot be presented as a new class of testing.

### 2.8 Change-aware evidence reuse and invalidation are already mature concepts in assurance engineering

Kokaly et al. (2016), *A model management approach for assurance case reuse due to system evolution*, MODELS 2016, pp. 196-206.

ACCESS: Assurance Case Centric Engineering of Safety-critical Systems (2024), Journal of Systems and Software 213, 112034, DOI 10.1016/j.jss.2024.112034.

What this work establishes:

- assurance claims can be explicitly linked to engineering artifacts and evidence;
- evolution of engineering artifacts can trigger change-impact analysis and re-evaluation of assurance cases;
- parts of an assurance case/evidence structure can be reused after change rather than reconstructed from zero;
- modern tooling can automatically evaluate traceability and invoke formal verification evidence.

Novelty impact: **major**.

This substantially weakens PUB-ME H3 in its previous form. The following are not generic novelty claims:

- evidence linked to claims;
- evidence becoming stale after software change;
- dependency-aware evidence invalidation;
- automated change-impact into an evidence/assurance structure;
- reusing still-valid evidence after evolution.

If H3 survives, it must be because scientific/numerical semantics require an additional layer that conventional software assurance does not capture, and that difference must be demonstrated empirically.

### 2.9 Simulation-specific assurance and continuous credibility are also established

Habli et al. (2020), *Enhancing COVID-19 decision making by creating an assurance case for epidemiological models*.

Ahmann et al. (2022), *Towards Continuous Simulation Credibility Assessment*, Asian Modelica Conference, DOI 10.3384/ecp193171.

NASA-STD-7009-related credibility literature and later simulation credibility frameworks similarly organize evidence around verification, validation, input pedigree, robustness, uncertainty, use history and technical review.

Novelty impact:

- PUB-ME cannot claim that simulation credibility should be evidence-based or continuously assessed as a new principle;
- a claim/evidence graph for a scientific model is not novel by itself.

What remains open:

- whether qualification authority for *behavior-preserving software evolution* can be made operational at the level of scientific state transitions and bounded migration semantics.

### 2.10 Workflow evolution provenance is mature prior art

Scientific workflow provenance literature distinguishes prospective provenance, retrospective provenance and workflow evolution provenance. E-SECO ProVersion (2016) and CWLProv-related work explicitly track workflow versions and computational provenance.

Novelty impact:

- version/provenance history of computational workflows is not novel;
- PUB-ME must distinguish provenance of an artifact from continued scientific validity of a previously admitted claim.

## 3. What is left after this pass

The candidate novelty has become much narrower.

No reviewed work in this pass was found that empirically combines all of the following **for the architectural modernization of a mature time-stepped process model**:

1. a declared accepted scientific state that is the sole authority for model history;
2. speculative candidate calculation that may fail/retry without becoming model history;
3. preservation evaluated over trajectory, conservation/accounting, restart and temporal state-transition semantics;
4. architecture migration sliced into bounded semantic changes rather than treated as a monolithic rewrite;
5. scientific claims linked to qualification evidence whose validity is adjudicated after each semantic change;
6. empirical comparison showing what this combined method detects or preserves beyond conventional output-regression-centered modernization;
7. longitudinal reuse of the same preserved reference denominator when later solver substitution and external coupling are introduced.

This is **not proof of priority**. It is the remaining search target.

## 4. Critical consequence: the current PUB-ME question is still too weak

The existing question:

> How can a mature process-based scientific model be structurally transformed while preserving defined scientific behaviour, provenance and qualification evidence?

still allows a reviewer to answer:

- Noah-MP / SUMMA / WaterGAP for modernization;
- E3SM for ongoing solution reproducibility;
- FLASH/Kelly for longitudinal scientific software evolution;
- behavior-preserving refactoring literature for equivalence;
- assurance-case literature for evidence impact and reuse;
- transaction/co-simulation literature for rollback and state acceptance.

Therefore a publishable paper should not ask only *how can this be done?*

## 5. Recommended research-question pivot

### Primary candidate RQ

> **Can explicit accepted-state authority and scientific claim-evidence dependencies detect or prevent semantic failures that output-regression-centered modernization does not, while preserving a bounded qualification burden during staged evolution of a mature time-stepped process model?**

Why this is stronger:

- it introduces a comparator rather than describing a method;
- it is falsifiable;
- it does not claim the individual software patterns are new;
- it asks whether their integration has observable scientific value;
- it permits a negative result if the added machinery detects nothing beyond conventional regression or does not reduce qualification ambiguity/cost.

### Supporting subquestions

#### RQ1a — preservation

Can representative SWAP4.3.1 scientific trajectories, balances and restart semantics be preserved across selected architectural migration slices inside a declared validity envelope?

This is necessary but not sufficient for novelty.

#### RQ1b — added protection

Which seeded or historically plausible state-transition faults can pass or evade ordinary successful-run output regression, yet be detected by explicit accepted/candidate/workspace authority checks?

This is the most important novelty-bearing experiment.

#### RQ1c — evidence continuity

For real migration changes, can scientific claim/evidence dependencies correctly classify prior evidence as reusable, replay-required, invalid or superseded, and how does that classification compare with blanket regression or code-dependency-only selection?

This is viable only if it demonstrates a scientifically meaningful distinction from generic change-impact analysis.

#### RQ1d — downstream denominator stability

When an alternative solver or external coupling path is attached later, can the original preservation denominator remain unchanged and independently qualified?

This remains an enabling result, not a claim about solver/coupling performance.

## 6. Required comparator

A major implication of this review is that PUB-ME now needs a credible baseline method.

Recommended baseline:

> **output-regression-centered modernization**

Defined minimally as:

- same input cases;
- successful-run outputs compared to a frozen reference;
- conventional regression/CI;
- no explicit candidate/accepted scientific state contract;
- no scientific claim/evidence dependency adjudication beyond normal test ownership.

The paper should avoid constructing a deliberately weak straw-man baseline. Where possible, the comparator should reflect practices documented in Noah-MP, SUMMA, WaterGAP, E3SM or established regression-testing literature.

## 7. Candidate experiments implied by the literature

### E-ME1 Preservation matrix

Purpose: show that the transformation still preserves defined scientific behavior.

Metrics:
- state trajectories;
- integrated fluxes;
- mass/accounting closure;
- accepted timestep sequence where relevant;
- restart/split-run continuation;
- declared exact/tolerance/statistical criteria.

Novelty role: denominator only.

### E-ME2 State-contamination challenge

Purpose: test whether explicit accepted/candidate authority detects failures that output regression can miss.

Candidate defect families:
- rejected candidate mutates committed physical state;
- retry reuses unauthorized candidate state;
- accepted flux/accounting is double-counted after retry;
- warm-start state becomes authoritative physical state;
- candidate from wrong origin revision/interval is committed;
- restart captures speculative rather than accepted state.

Design rule:
- use seeded mutations or historical defects only when scientifically plausible;
- pre-register each defect and predicted observability before running the comparison;
- record whether conventional successful-run regression, transaction-specific invariant tests, or both detect it.

### E-ME3 Evidence-impact challenge

Purpose: test change-aware scientific qualification against generic alternatives.

For a sample of real migration slices:
- define the scientific claims/invariants affected;
- compare full-suite replay, code-dependency test selection, and scientific claim/evidence selection;
- measure tests/evidence selected, runtime/cost, missed seeded impacts and false-positive replay burden;
- classify evidence reuse/invalidation decisions prospectively where possible.

A positive PUB-ME result requires more than fewer tests. It must preserve relevant scientific fault-detection coverage.

### E-ME4 Longitudinal denominator challenge

Purpose: test whether later solver/coupling work can be added without moving the preservation denominator.

Observe:
- whether reference scientific state contract changes;
- whether old preservation evidence remains valid or must be replayed;
- whether alternative solver/coupling claims stay separable from PUB-ME claims.

## 8. Strong falsification criteria after pass 2

PUB-ME should be narrowed or abandoned as a standalone method paper if any of the following occurs:

1. a close prior paper is found that already combines accepted scientific state authority, staged modernization and scientific-evidence change impact in a comparable process model;
2. E-ME2 finds no plausible defect class for which explicit state authority adds detection/prevention beyond standard regression and ordinary invariant testing;
3. E-ME3 reduces to generic regression test selection with renamed domain metadata;
4. scientific claim/evidence selection misses relevant seeded impacts or requires nearly full-suite replay in practice;
5. the method's only demonstrable benefit is code cleanliness or governance traceability;
6. the only strong results actually belong to solver substitution or coupling papers.

## 9. Current feasibility verdict

**PUB-ME remains plausible, but its novelty is now conditional on empirical added value rather than architectural originality.**

The strongest possible paper is no longer:

> We developed a novel architecture for safe model modernization.

A more defensible form is:

> We evaluated whether explicit scientific-state authority and scientific claim/evidence dependencies provide measurable protection beyond output-regression-centered modernization during the staged evolution of a mature process model.

This framing survives the second literature pass better because it treats known software-engineering mechanisms as prior art and makes their scientific value in a specific model-evolution setting the object of study.

## 10. Sources added in this pass

Peer-reviewed / conference prior art:

- Mahajan, S. et al. (2019). Ongoing solution reproducibility of earth system models as they progress toward exascale computing. *International Journal of High Performance Computing Applications*, 33(5), 784-790. DOI 10.1177/1094342019837341.
- Dubey, A. et al. (2014). Evolution of FLASH, a multi-physics scientific simulation code for high-performance computing. *International Journal of High Performance Computing Applications*, 28(2), 225-237. DOI 10.1177/1094342013505656.
- Dubey, A. et al. (2013). The software development process of FLASH, a multiphysics simulation code. IEEE SE-CSE. DOI 10.1109/SECSE.2013.6615093.
- Kelly, D. (2009). Determining factors that affect long-term evolution in scientific application software. *Journal of Systems and Software*, 82(5), 851-861. DOI 10.1016/j.jss.2008.11.846.
- AlOmar, E. et al. (2021). On preserving the behavior in software refactoring: A systematic mapping study. *Information and Software Technology*, 140, 106675. DOI 10.1016/j.infsof.2021.106675.
- Hoverd, T. and Sampson, A. T. (2010). A Transactional Architecture for Simulation. IEEE ICECCS, 286-290. DOI 10.1109/ICECCS.2010.7.
- Andelfinger, P. and Uhrmacher, A. M. Synchronous speculative simulation of tightly coupled agents in continuous time on CPUs and GPUs. *SIMULATION*. DOI 10.1177/00375497231158930.
- Lin, X., Simon, M. and Niu, N. (2018/2020). Exploratory Metamorphic Testing for Scientific Software. *Computing in Science & Engineering*, 22(2), 78-87. DOI 10.1109/MCSE.2018.2880577.
- Clark et al. (2023). Testing Causality in Scientific Modelling Software. *ACM Transactions on Software Engineering and Methodology*. DOI 10.1145/3607184.
- Kokaly, S. et al. (2016). A model management approach for assurance case reuse due to system evolution. MODELS 2016, 196-206.
- ACCESS (2024). Assurance Case Centric Engineering of Safety-critical Systems. *Journal of Systems and Software*, 213, 112034. DOI 10.1016/j.jss.2024.112034.
- Habli, I. et al. (2020). Enhancing COVID-19 decision making by creating an assurance case for epidemiological models.
- Ahmann, M. et al. (2022). Towards Continuous Simulation Credibility Assessment. Asian Modelica Conference. DOI 10.3384/ecp193171.
- E-SECO ProVersion (2016). An Approach for Scientific Workflows Maintenance and Evolution. *Procedia Computer Science*, 100, 547-556. DOI 10.1016/j.procs.2016.09.194.
- Khan et al. (2019). Sharing interoperable workflow provenance: a review of best practices and their practical application in CWLProv. *GigaScience*, 8(11), giz095. DOI 10.1093/gigascience/giz095.

Emerging / non-peer-reviewed priority-risk source:

- Coleman, E. et al. (2026). Validating LLM-Modernized Scientific Software Through Differential Fault Injection. arXiv:2608.14527.

## 11. Next literature pass

The highest-value next searches are no longer broad modernization searches. They should target the exact remaining gap:

1. scientific claim/evidence dependency models for numerical simulation;
2. semantic regression selection based on physical invariants/conservation laws;
3. mutation/fault-seeding studies for scientific model state-transition errors;
4. incremental verification or assurance specifically for PDE/process-model software;
5. comparable empirical studies that measure the cost and fault-detection trade-off of selective scientific requalification.

If those searches find a close equivalent, the RQ must be narrowed again before manuscript experiments continue.