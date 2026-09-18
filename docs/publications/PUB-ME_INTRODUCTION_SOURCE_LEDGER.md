# PUB-ME introduction claim and source ledger

Status: **living manuscript-support ledger, not final prose**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Review date: 2026-09-18

Purpose: preserve the exact literature logic needed to introduce the paper without overstating novelty. Each claim records both supporting literature and the boundary that the manuscript must respect.

## I1 — Mature scientific models are long-lived executable scientific assets

### Candidate introduction point

Process-based environmental models often accumulate scientific assumptions, numerical methods and implementation history over decades. Software evolution is therefore not separable from scientific reproducibility and confidence in model results.

### Sources

- Kanewala and Bieman (2014), *Testing Scientific Software: A Systematic Literature Review*, Information and Software Technology 56(10), 1219-1232. DOI 10.1016/j.infsof.2014.05.006.
- Peng et al. (2021), *Unit and regression tests of scientific software: A study on SWMM*, Journal of Computational Science 53, 101347. DOI 10.1016/j.jocs.2021.101347.
- Gregor et al. (2026), *Best practices in software development for robust and reproducible geoscientific models...*, GMD 19, 2407-2436. DOI 10.5194/gmd-19-2407-2026.

### Safe interpretation

These sources support the importance and difficulty of maintaining/testing scientific models.

### Do not claim

- that scientific software testing is immature in every community;
- that SWAP is uniquely long-lived;
- that software engineering practice is absent from geoscience.

## I2 — Behavior-preserving modernization of hydrologic/land models is established prior art

### Candidate introduction point

Recent hydrologic and land-model studies already demonstrate that mature process models can be substantially refactored or reprogrammed while aiming to preserve scientific behavior and improve maintainability/interoperability.

### Sources

- He et al. (2023), *Modernizing ... Noah-MP land surface model (version 5.0)*, GMD 16, 5131-5151. DOI 10.5194/gmd-16-5131-2023.
- Nyenah et al. (2025), *The process and value of reprogramming a legacy global hydrological model*, GMD 18, 5635-5653. DOI 10.5194/gmd-18-5635-2025.
- Trim et al. (2025), *Enhancing the modularity and interoperability of hydrologic models: A demonstration with SUMMA*, Environmental Modelling & Software 194, 106668. DOI 10.1016/j.envsoft.2025.106668.

### Safe interpretation

The problem `modernize a hydrologic model while retaining scientific behavior` is not itself novel.

### Do not claim

- novelty for modularization, modern Fortran, new data structures, component interfaces or preserved output alone.

## I3 — Scientific reproducibility during software/infrastructure change is established

### Candidate introduction point

Earth-system modelling research has already developed explicit methods for testing whether software-infrastructure, compiler or library changes cause scientifically meaningful solution changes when no science change is intended.

### Sources

- Mahajan et al. (2019), *Ongoing solution reproducibility of earth system models as they progress toward exascale computing*, International Journal of High Performance Computing Applications 33(5), 784-790. DOI 10.1177/1094342019837341.
- Baker et al./time-step convergence and ensemble consistency literature cited by that work.
- Gregor et al. (2026), GMD 19, 2407-2436.

### Safe interpretation

Continuous/ongoing preservation testing is prior art.

### Do not claim

- that SWAP5 introduces continuous verification;
- that bit-for-bit or tolerance/statistical reproducibility testing is new.

## I4 — Regression testing is established in long-lived environmental models

### Candidate introduction point

Previous model versions can serve as numerical regression oracles, and real environmental modelling projects already maintain extensive unit and regression test collections.

### Sources

- Peng et al. (2021), SWMM study: 2953 unit tests and 58 regression tests analyzed; numerical regression uses earlier/reference output as an oracle.
- Farrell et al. (2011), *Automated continuous verification for numerical simulation*, GMD 4, 435-449.

### Safe interpretation

A legacy-output comparator is credible baseline practice, not a straw man but also not the complete scientific-software testing state of the art.

### Do not claim

- that regression testing alone represents best current practice.

## I5 — Scientific-software testing already includes metamorphic, causal and mutation-based techniques

### Candidate introduction point

The test-oracle problem in scientific computing has motivated metamorphic, mutation-sensitivity and causal testing methods that can expose faults beyond direct expected-output comparison.

### Sources

- Kanewala and Bieman (2014), systematic review.
- *Investigating test selection techniques for scientific software using Hook's mutation sensitivity testing* (2010), Procedia Computer Science 1(1), 1487-1494. DOI 10.1016/j.procs.2010.04.165.
- Peng/Lin/Niu SWMM-related metamorphic-testing work, including *Exploratory Metamorphic Testing for Scientific Software*.
- *Testing Causality in Scientific Modelling Software* (2023), ACM TOSEM. DOI 10.1145/3607184.
- Clark, Dan and Hierons (2013), *Semantic mutation testing*, Science of Computer Programming 78(4), 345-363. DOI 10.1016/j.scico.2011.03.011.

### Safe interpretation

The PUB-ME experiment must compare transition-authority checks against a strong baseline, not merely output regression.

### Do not claim

- novelty for fault injection, semantic mutation, metamorphic testing or adversarial testing themselves.

## I6 — Rejected-step rollback and accepted/rejected lifecycle are established numerical concepts

### Candidate introduction point

Adaptive integration and co-simulation frameworks already distinguish accepted and rejected steps and may restore prior state before retrying. Mature libraries also make lifecycle callbacks depend explicitly on rollback outcome.

### Sources / technical anchors

- PETSc TS accepted/rejected-step and rollback semantics, including `TSSetPostEvaluate` lifecycle documentation.
- Sandia Aria timestep-failure/retry semantics.
- FMI/FMI++ state save/restore and rollback literature.
- Braun and Fritzson (2022), *Numerically robust co-simulation using transmission line modeling and the Functional Mock-up Interface*, SIMULATION 98(11). DOI 10.1177/00375497221097128.

### Safe interpretation

The individual mechanics of rollback/retry are not novel.

### Do not claim

- invention of transaction semantics, checkpoint/restore, speculative evaluation or accepted/rejected steps.

## I7 — Rejected-step side effects are a plausible real defect class

### Candidate introduction point

Even when rollback itself is supported, side effects can be semantically misplaced relative to the accepted/rejected-step boundary. This motivates testing not only state restoration but also accounting, restart and publication effects.

### Plausibility source

- Diffrax issue #464 (2024), *activating the event on a rejected step*.

### Evidence status

Non-peer-reviewed software issue. Use at most as a motivating anecdote or discussion example, never as novelty evidence.

### Safe interpretation

The defect family is realistic enough to study experimentally.

### Do not claim

- prevalence of this defect class in scientific software;
- peer-reviewed confirmation from this source.

## I8 — Evidence/change-impact reasoning is established outside environmental modelling

### Candidate introduction point

Software evolution research and safety-assurance engineering already use dependency/traceability models to identify the effects of changes and determine which tests, proofs or assurance claims may need reevaluation.

### Sources

- Li and Sun (2013), *A survey of code-based change impact analysis techniques*, Software Testing, Verification and Reliability 23, 613-646. DOI 10.1002/stvr.1475.
- Palmskog, Celik and Gligoric (2020), *Practical Machine-Checked Formalization of Change Impact Analysis*, TACAS 2020.
- ACCESS (2024), *Assurance Case Centric Engineering of Safety-critical Systems*, Journal of Systems and Software. DOI 10.1016/j.jss.2024.112034.
- Smith, Sayari Nejad and Wassyng, *Building Confidence in Scientific Computing Software Via Assurance Cases* (scientific-computing assurance case literature).

### Safe interpretation

Generic claim-evidence dependencies and selective re-evaluation are prior art.

### Do not claim

- novelty for an evidence graph or selective regression in itself.

## I9 — The remaining gap is an empirical integration problem, not an architectural invention claim

### Candidate introduction point

The reviewed literature treats model modernization, scientific testing, rollback/state restoration and evidence/change-impact reasoning largely as separate concerns. The targeted gap is whether explicit authority at the candidate-to-accepted scientific-state transition provides measurable incremental protection during modernization of a mature stateful process model when compared with a strong conventional scientific-software baseline.

### Evidence basis

- bounded negative result of `PUB-ME_LITERATURE_REVIEW_PASS4_TEMPORAL_STATE_TRANSITION.md`;
- no identified peer-reviewed close comparator combining the six specified elements as one empirical modernization study.

### Safe wording for eventual manuscript

Prefer:

> `To our knowledge, prior studies have addressed behavior-preserving model modernization, scientific-software testing, rollback-capable simulation, and change-aware assurance separately. We investigate whether making the candidate-to-accepted scientific-state boundary an explicit qualification target provides measurable additional protection during model modernization.`

Only use wording of this kind after the literature review is closed near submission.

### Do not write

- `for the first time`;
- `unique`;
- `no prior work exists`;
- `transactional scientific modelling is new`.

## I10 — Scientific merit must come from the experiment, not the rewrite narrative

### Candidate introduction/discussion point

The publication risk of software-modernization papers is visible in the WaterGAP review history: reviewers questioned scientific merit when development work was not sufficiently framed as a scientific contribution. The final WaterGAP paper is valuable prior art, but PUB-ME should avoid relying on development effort itself as the research result.

### Source

- Open peer-review discussion for Nyenah et al. (2025), GMD 18, 5635-5653.

### Safe interpretation

Use this internally to enforce manuscript design. It need not be cited in the manuscript unless discussing publication methodology.

## I11 — Recent emerging work raises the bar further

### Candidate review note

Recent 2026 preprints investigate semantic mutation operators and differential fault-injection approaches for modernized scientific-computing code. These are not yet treated as settled peer-reviewed authority but increase priority risk for broad claims around `adversarial modernization testing`.

### Use

- monitor through manuscript submission;
- cite only with explicit preprint status if materially relevant;
- do not base core novelty on the generic use of semantic mutants.

## I12 — Proposed final introduction logic

The current safest narrative sequence is:

1. mature environmental models are long-lived scientific software whose implementation affects reproducibility;
2. behavior-preserving modernization is already established in hydrologic/land models;
3. testing and ongoing reproducibility during software evolution are also established;
4. modern scientific-software testing already extends beyond direct output regression;
5. accepted/rejected-step rollback and state restoration are mature numerical concepts;
6. change-aware evidence management exists in software/assurance engineering;
7. the unresolved question is therefore not whether these mechanisms exist, but whether an explicit candidate-to-accepted **scientific transition authority** provides measurable incremental protection against contamination of accepted model history during modernization;
8. the paper tests that question with preregistered D1-D6 semantic defects against a strong conventional comparator in SWAP4.3.1/SWAP5.

This ledger should be updated whenever a new source removes, weakens or strengthens one of these claims.