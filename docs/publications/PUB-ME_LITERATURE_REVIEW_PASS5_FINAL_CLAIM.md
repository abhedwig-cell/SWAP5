# PUB-ME literature review pass 5: final narrowed claim check

Status: **TARGETED_NOVELTY_RECHECK_AFTER_D1_D6**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Review date: 2026-09-18

## 1. Exact claim searched

After D1-D6, the candidate standalone contribution is no longer broad model modernization, rollback, adversarial testing or evidence preservation.

The exact remaining claim under review is:

> During staged modernization of a mature time-stepped process model, explicit authority at the transition from candidate computation to accepted scientific history can structurally prevent or localize scientifically consequential contamination before it propagates into accepted state, accounting, restart, numerical continuation or external publication, beyond the detection timing of a strong conventional scientific-software qualification baseline.

This pass searches for prior work capable of falsifying that combined claim.

## 2. Search focus

Targeted combinations included:

- accepted state + rejected trial + scientific simulation;
- rollback + side effect + numerical solver;
- candidate/committed state + scientific software modernization;
- accepted scientific history + restart/publication contamination;
- legacy scientific model refactoring + rejected timestep semantics;
- scientific software fault injection + modernization.

Searches intentionally included numerical-analysis, ODE/PDE, simulation, hydrology/environmental modelling, legacy scientific software and software-engineering terminology.

## 3. Findings that further constrain novelty

### 3.1 Rejected-step rollback remains clear prior art

Numerical solvers and environmental-model engines already implement accepted/rejected timestep semantics and rollback of prognostic state.

A current OpenSWMM finite-volume engine description, for example, explicitly states that rejected substeps roll the prognostic state back and retry with a reduced step.

Consequence:

- PUB-ME cannot claim the rule “rejected state must not become accepted state” as a new numerical principle;
- the manuscript must focus on the architectural-evolution problem and the experimentally observed authority boundary across several scientific-history channels.

### 3.2 Side effects on rejected steps are a plausible real software failure mode

A Diffrax issue reported a terminating event being triggered even though the integration step was rejected; maintainers explicitly recognized the behavior as undesirable.

This is non-peer-reviewed implementation evidence and cannot establish novelty.

It does support the plausibility of D6-like contamination as a real integration failure class rather than a purely invented SWAP-specific mutant.

### 3.3 Scientific-software modernization literature continues to expand

Solovjev et al. (2026), *Reengineering of the cascade reconstruction in the Baikal-GVD experiment: principles of working with legacy scientific software*, describes stepwise modernization of legacy Fortran into a modern C++ framework with verification at each stage and preservation of physical validity.

This further removes novelty from:
- staged migration;
- verification after each modernization step;
- preservation of physical/scientific validity;
- modularization as such.

The reviewed abstract does not establish a candidate-to-accepted scientific-history authority experiment comparable to D1-D6.

### 3.4 Adversarial modernization validation is rapidly emerging

Coleman et al. (2026 preprint), *Validating LLM-Modernized Scientific Software Through Differential Fault Injection*, performs paired deterministic fault injection against original and modernized scientific Fortran software across more than 2,200 runs.

Consequence:

- adversarial validation, fault injection and off-nominal equivalence cannot be presented as PUB-ME novelty;
- the D1-D6 contribution, if retained, must be the semantic transition-authority question and its timing/structural result, not the fact that faults were injected.

The source is currently treated as emerging/preprint evidence, not peer-reviewed novelty authority.

## 4. Search result on the exact combined claim

This targeted pass did **not** identify a peer-reviewed scientific-software modernization study that simultaneously:

1. modernizes an established stateful scientific/process model;
2. defines an explicit candidate-to-accepted scientific-history authority boundary;
3. tests contamination across multiple authority objects such as physical state, accounting, restart, solver workspace and external publication;
4. compares a strong conventional scientific-software baseline against direct transition-authority checks;
5. distinguishes structural prevention from earlier or unique detection;
6. uses the result as an empirical criterion for the modernization method.

This is a bounded search result, **not proof of international priority**.

The literature remains heterogeneous and terminology differs between numerical analysis, simulation software, hydrology, software evolution and assurance engineering.

## 5. Novelty statement that remains unsafe

Do not write:

- “we introduce transactional simulation”;
- “we introduce rollback-safe scientific modelling”;
- “we are the first to protect accepted state from rejected steps”;
- “we introduce adversarial testing of modernized scientific software”;
- “we introduce change-aware evidence”;
- “existing regression tests cannot find these faults”.

D1-D6 itself shows that strong B1 does detect D2/D4/D5/D6 after the relevant operation.

## 6. Candidate manuscript novelty statement after D1-D6

A defensible bounded formulation is:

> We evaluate whether explicit transition-authority contracts provide incremental protection during architectural modernization of a mature process-based simulator. Across preregistered contamination families, the contracts either structurally prevent invalid transitions or localize authority violations before rejected/speculative computation is allowed to propagate into subsequent computation, accepted accounting, persistence or external publication. Strong conventional qualification still detects the executable mutants later; the observed contribution is therefore prevention/localization at the scientific-authority boundary rather than unique fault detection.

This wording remains provisional until:
- D2 physical-regime replication;
- preservation-denominator evidence;
- final manuscript literature closure.

## 7. Publication-risk assessment

### Reduced risks

The final claim no longer competes directly with:
- Noah-MP/SUMMA/WaterGAP-style modernization;
- continuous verification;
- rollback or adaptive-step algorithms;
- generic fault injection;
- generic change-impact analysis.

### Remaining risks

1. **Obviousness risk**  
   Reviewers may judge precondition checks around accepted state as sound software engineering rather than a scientific-method contribution.

2. **Single-system risk**  
   All primary experiments are within SWAP5 infrastructure.

3. **Seeded-mutant risk**  
   D1-D6 use qualification-only fault operators rather than naturally occurring historical production defects.

4. **Timing-only risk**  
   No executable family establishes UNIQUE_DETECTION; most incremental evidence is earlier localization.

5. **Terminology risk**  
   “scientific authority” must remain operational and measurable rather than rhetorical.

## 8. Conditions for overcoming the remaining risks

The paper needs all of the following:

- a strong legacy/scientific denominator preservation section;
- explicit strong B1 comparator definition;
- transparent negative/blocked experiments and harness corrections;
- D2 physical-regime replication;
- a cross-defect mechanism synthesis rather than six independent-success counting;
- at least one realistic end-to-end SWAP illustration;
- careful connection between earlier detection and prevention of an irreversible/propagating scientific-history action;
- no priority claim stronger than the review supports.

## 9. Pass-5 verdict

`NO_CLOSE_EQUIVALENT_IDENTIFIED__NOVELTY_REMAINS_PLAUSIBLE_BUT_NOT_PROVEN`

The narrowed standalone contribution remains defensible enough to continue, but only with the bounded claim above.
