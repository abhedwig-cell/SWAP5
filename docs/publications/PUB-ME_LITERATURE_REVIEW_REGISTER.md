# PUB-ME literature review and novelty register

Status: **living critical review, initial targeted pass**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

First review date: 2026-09-18

## 1. Purpose

This register is not a bibliography assembled to support a predetermined novelty claim. Its purpose is to try to falsify the proposed `PUB-ME` contribution before manuscript drafting.

For every relevant source, record:

1. what the source already establishes;
2. what it does not establish;
3. which proposed `PUB-ME` novelty is therefore weakened, removed, or remains open;
4. how the source may legitimately be used in the manuscript introduction or discussion.

The central question is not whether SWAP5 is technically sophisticated. It is whether a scientifically defensible, transferable research contribution remains after close prior work is taken seriously.

## 2. Current research-question concern

Current contract question:

> How can a mature process-based scientific model be structurally transformed while preserving defined scientific behaviour, provenance and qualification evidence?

Initial literature review shows that this question is too broad to carry the novelty claim by itself. Legacy-model rewriting, modular refactoring, preservation of model outputs, continuous verification, regression testing, standardized component interfaces, rollback/retry mechanisms, software provenance, and change-impact-aware regression testing all have substantial prior art.

The candidate novelty must therefore be narrower and operationally testable.

### Provisional sharper question

> How can scientific state authority and qualification evidence be preserved and re-established during staged architectural evolution of a mature time-stepped process model, including candidate execution, rejection, retry and later component substitution?

This is a working question only. It must be narrowed further if the literature reveals an existing method that already combines the same execution and evidence semantics.

### Operational meaning of scientific authority

For this review, `scientific authority` means the explicit answer to three linked questions:

- which model state is the accepted scientific trajectory and which state is still speculative;
- which state transitions are admissible after failure, rejection, retry, restart or substitution;
- which qualification evidence remains valid after a software change and which evidence must be replayed, superseded or invalidated.

The term must not be used rhetorically. Any manuscript use requires executable evidence for these distinctions.

## 3. Close prior work matrix

| Source | What it establishes | What it does not establish in the reviewed material | Consequence for PUB-ME | Likely manuscript role |
| --- | --- | --- | --- | --- |
| He et al. (2023), *Modernizing the open-source community Noah-MP land surface model (v5.0)*, GMD 16, 5131-5151, DOI 10.5194/gmd-16-5131-2023 | Direct hydrologic/land-model precedent for a physics-preserving refactor using modern Fortran, modular process structure, new data structures, coupling interfaces, technical documentation, benchmarks, and hierarchical bit-for-bit tests. The paper reports exact agreement between refactored and base simulations across several benchmark scales and physics combinations. | The paper is organized around modernization, modularity, interoperability and benchmarking. The reviewed sections do not formulate committed-versus-candidate state authority, rejected-trial contamination, or longitudinal qualification-evidence invalidation/reuse as the research object. | Removes any novelty claim based on modern Fortran, modular process decomposition, better data structures, coupling readiness, benchmark datasets, or even bit-for-bit behavior preservation during refactoring. | Strongest early introduction comparator showing that behavior-preserving modernization of a major process model is already publishable and already well demonstrated. |
| Nyenah et al. (2025), *The process and value of reprogramming a legacy global hydrological model*, GMD 18, 5635-5653, DOI 10.5194/gmd-18-5635-2025 | Direct hydrological precedent for rewriting a mature model for sustainability and reproducibility, with modular architecture, testing, documentation, automation and FAIR4RS assessment while intending similar scientific output rather than improved physics. | Primary emphasis is sustainable research software and the reprogramming process. The reviewed article does not make trial/commit semantics or dependency-aware scientific-evidence authority the central method. | Eliminates novelty based on “legacy hydrological model rewrite with preserved results”, sustainable architecture, CI, documentation or FAIR practices. | Establish the immediate research-software context and distinguish PUB-ME from a sustainability/rewrite paper. |
| Trim et al. (2025), *Enhancing the modularity and interoperability of hydrologic models: A demonstration with SUMMA*, Environmental Modelling & Software 194, 106668, DOI 10.1016/j.envsoft.2025.106668 | Presents a general hierarchical architecture for process-based hydrologic/land models, refactors numerical and physical components, uses initialize-update-finalize, improves interoperability and BMI compatibility, and verifies that outputs do not substantially change. | In the reviewed material, the contribution is component architecture and interoperability rather than an explicit scientific-state transaction model for failed/retried whole timesteps or a longitudinal evidence-admission method. | Very close comparator. Removes novelty based on modularity, composable components, numerical/physics separation, initialize-update-finalize, BMI readiness and output-preserving refactoring. | Must be discussed prominently. PUB-ME must answer a different question than SUMMA, not merely apply similar ideas to SWAP. |
| Farrell et al. (2011), *Automated continuous verification for numerical simulation*, GMD 4, 435-449, DOI 10.5194/gmd-4-435-2011 | Argues that verification of evolving geoscientific numerical software must be continuous and automated rather than a one-time end-of-development activity. | Does not, by itself, define the SWAP5-style state-authority lifecycle or the proposed evidence dependency/admission semantics. | Removes novelty from “continuous verification while the model evolves” and from automation of verification as such. | Foundational source for why evolving models need ongoing verification; motivates but does not constitute PUB-ME novelty. |
| Kanewala and Bieman (2014), *Testing scientific software: A systematic literature review*, Information and Software Technology 56, 1219-1232, DOI 10.1016/j.infsof.2014.05.006 | Establishes that scientific software has special testing difficulties including oracle problems, legacy structures, numerical behavior and weak systematic testing practice. Reviews unit, integration, system and regression testing. | Does not provide a domain-specific modernization protocol combining accepted-state semantics with evidence admission. | Removes claims that regression/testing difficulties of scientific software are newly identified. | Background for why ordinary software tests do not automatically settle scientific correctness/preservation. |
| Peng et al. (2021), *Unit and regression tests of scientific software: A study on SWMM*, Journal of Computational Science 53, 101347, DOI 10.1016/j.jocs.2021.101347 | Empirically studies thousands of unit tests and dozens of regression tests in a long-lived environmental model. Shows previous-version outputs can serve as regression oracles, with scientific/numerical caveats. | Does not turn regression results into an explicit evolving scientific-evidence authority graph or address speculative timestep state ownership. | Removes novelty from using legacy/reference output as a regression oracle. | Environmental-model evidence that regression testing is established; supports need to explain why PUB-ME goes beyond regression testing. |
| AlOmar et al. (2021), *On preserving the behavior in software refactoring: A systematic mapping study*, Information and Software Technology 140, 106675 | Maps a large body of behavior-preserving refactoring research and techniques. Behavior preservation is a foundational refactoring concern, not a new idea. | Generic software-refactoring literature does not automatically address conservation laws, numerical tolerance, scientific state trajectories or model-specific qualification authority. | Removes any generic claim that behavior-preserving refactoring itself is novel. | Boundary source. Introduction should explicitly separate software behavior preservation from preservation of defined scientific semantics. |
| Durak (2015), *Extending the Knowledge Discovery Metamodel for architecture-driven simulation modernization*, SIMULATION 91(12), 1052-1067 | Treats simulation-software modernization as a distinct architecture-driven problem and provides model-driven modernization concepts. | Not a demonstrated hydrological model-evolution method centered on scientific state authority and numerical qualification evidence. | Removes novelty from claiming that simulation modernization is an unexplored research problem. | Positions PUB-ME relative to simulation modernization rather than generic application modernization. |
| Hutton et al. (2020), *Basic Model Interface 2.0: A standard interface for coupling numerical models in the geosciences*, JOSS 5(51), 2317, DOI 10.21105/joss.02317 | Standardizes model query/control functions for interoperability and coupling. Initialize/update/finalize-style external model control is established practice. | BMI does not, by itself, prescribe internal accepted/candidate state ownership, rollback-safe scientific history, or qualification evidence validity after refactoring. | Removes novelty from standard control interfaces and coupling-ready APIs. | Explain that interoperability interfaces are necessary but not sufficient for the proposed scientific-state/evidence problem. |
| OpenMI 2.0 literature, including the 2019 Environmental Modelling & Software overview | Establishes long-standing standards and methods for integrating environmental numerical models and exchanging quantities across model boundaries. | Model integration standards are not themselves a migration/qualification method for preserving authority during architectural replacement of a legacy model. | Removes novelty from environmental model interoperability/coupling as a concept. | Context for later PhD coupling papers and for delimiting PUB-ME. |
| Barker et al. (2022), *Introducing the FAIR Principles for research software*, Scientific Data 9, 622, DOI 10.1038/s41597-022-01710-x | Establishes FAIR4RS, including software provenance, interoperability, versioning and reuse as first-class research-software concerns. | FAIR4RS is not an executable semantic preservation/admission protocol and does not decide whether prior numerical evidence remains scientifically valid after a particular code change. | Removes novelty from software provenance, versioning and research-software traceability alone. | Background for software provenance and reuse; distinguish artifact provenance from validity of a scientific claim after change. |
| Braun and Fritzson (2022), *Numerically robust co-simulation using transmission line modeling and the Functional Mock-up Interface*, SIMULATION 98(11), DOI 10.1177/00375497221097128 | Explicitly discusses rollback as a known capability required by iterative co-simulation and conservative step-size/relaxation methods. | Does not claim rollback as a scientific-software modernization method or address migration evidence authority. | Removes any claim that rollback or recomputation from prior state is intrinsically novel. | Important boundary: PUB-ME novelty cannot be “we invented rollback”. |
| PETSc TS adaptive time-stepping documentation/source | Mature numerical infrastructure explicitly distinguishes accepted and rejected stages/steps, retries rejected steps with changed timestep, and handles nonlinear solve failures. | A time integrator's accept/reject mechanism is not equivalent to a whole legacy scientific-model migration method with state ownership and longitudinal qualification evidence. | Removes novelty from numerical timestep acceptance/rejection semantics in isolation. | Boundary source to state that step rejection is established numerical practice; the proposed contribution, if any, lies in elevating comparable authority semantics to the evolving scientific-model architecture and its evidence. |
| Li and Sun (2013), *A survey of code-based change impact analysis techniques*, Software Testing, Verification and Reliability 23, 613-646; Palmskog et al. (2020), *Practical Machine-Checked Formalization of Change Impact Analysis* | Change-impact analysis and dependency-based regression-test selection are mature software-engineering topics; impacted tests/elements can be selected based on change/dependency graphs. | These methods reason about software components/tests, not automatically about the scientific validity domain of numerical evidence, corrected historical references, conservation/restart contracts or semantic-successor evidence. | Weakens any generic claim that dependency-aware evidence replay is new. PUB-ME must show why scientific claim/evidence dependencies are materially different or provide additional semantics. | Essential adversarial comparator for H3. |
| ACCESS and assurance-case evolution literature (e.g. JSS 2024) | Safety-critical software already studies evidence-linked assurance cases and the need to re-evaluate evidence when engineering artifacts evolve. | This is not process-based environmental modelling and does not directly solve numerical scientific-equivalence/state-trajectory qualification. | Further narrows H3: “evidence invalidation after software change” is not novel in general. Any contribution must be specific to executable scientific semantics and demonstrate value beyond generic assurance/change-impact methods. | Use mainly in discussion or method boundary, unless deeper review shows a direct reusable framework that falsifies H3. |

## 4. Preliminary synthesis: what is definitely not novel

The review already rules out the following as primary novelty claims:

- rewriting or refactoring a legacy hydrological/environmental model;
- preserving model outputs during refactoring;
- modularizing process code;
- separating physical-process representation from numerical methods;
- introducing modern Fortran/data structures;
- initialize-update-finalize lifecycle functions;
- BMI/OpenMI-style interoperability;
- unit tests, regression tests, CI or continuous verification;
- using a previous model version as a numerical regression oracle;
- software provenance and FAIR research-software practice;
- timestep rejection, retry or rollback in numerical methods or co-simulation;
- generic software change-impact analysis or selective regression testing;
- generic evidence/assurance re-evaluation when software changes.

Any manuscript framed mainly around these contributions is at high risk of being a software-development report rather than an independent scientific-method paper.

## 5. Candidate gap that remains open

No reviewed source in this initial pass has yet been found that combines, as one explicit method for evolving a mature time-stepped scientific model:

1. an authoritative accepted scientific state separated from speculative candidate execution and disposable solver workspace;
2. explicit rejection/retry/rollback semantics that prevent failed candidate work from becoming scientific history;
3. behavior preservation defined over scientific trajectories, balances, restart semantics and state transitions rather than only final program output or generic external behavior;
4. staged architectural migration in bounded semantic slices with declared scientific claims and nonclaims;
5. qualification evidence linked to those semantic dependencies so old evidence is explicitly replayed, reused, invalidated or replaced by a semantic successor as the architecture evolves;
6. longitudinal demonstration that this method remains workable when later numerical implementations and coupling capabilities are introduced without silently changing the original scientific denominator.

This is **not yet a novelty claim**. It is the current search target to falsify.

## 6. Critical distinction from closest hydrologic papers

### Noah-MP

Noah-MP is especially important because it already demonstrates staged component refactoring plus bit-for-bit hydrological preservation. PUB-ME therefore needs evidence that its additional state-authority and evidence-admission semantics solve a problem not addressed by bit-for-bit component benchmarking alone.

A convincing experiment would expose a case in which ordinary output-regression success is insufficient to prove safe evolution, for example a rejected candidate that could contaminate later accepted history, or an apparently green old qualification whose dependency has changed and therefore must be invalidated or semantically replayed.

### SUMMA

SUMMA is especially important because it already gives a general architecture, component standards, numerical/physical separation and output-preserving refactoring. PUB-ME should not compete on modular architecture. Its candidate distinction is the *authority of state transitions and evidence during evolution*.

### WaterGAP

WaterGAP is especially important because it shows that the reprogramming process itself can be published. Its open peer review also demonstrates the publication risk: reviewers initially questioned scientific merit when the paper read mainly as a description of development rather than a scientific argument. PUB-ME should therefore begin from explicit hypotheses and experiments, not from a chronology of SWAP5 development.

## 7. Provisional paper hypotheses after literature challenge

### H1: accepted scientific trajectory preservation

Architectural decomposition can preserve a predefined scientific trajectory and accounting envelope while making speculative candidate execution and accepted state explicitly distinct.

This is stronger than final-output regression and must be tested across state trajectories, balances, restart and failed/retried execution.

### H2: state-authority separation has observable protection value

Explicit accepted/candidate/workspace separation prevents or exposes semantic contamination that would not necessarily be detected by normal successful-run equivalence testing.

This hypothesis requires adversarial evidence, not an architecture diagram.

### H3: scientific evidence continuity can be made change-aware

For a long-running model migration, qualification evidence can be classified as reusable, replay-required, invalidated or superseded based on explicit scientific/semantic dependencies rather than blanket requalification or unexamined historical tests.

This hypothesis is now under strong prior-art pressure from generic change-impact and assurance-case research. It remains viable only if the scientific semantics add a demonstrable, nontrivial layer beyond ordinary code/test dependencies.

### H4: the method creates independent experimental capability

Once the reference scientific state and acceptance lifecycle are explicit, later solver substitution or coupling can use the same accepted-state denominator without turning those later scientific results into part of the modernization claim.

This is an enabling result only. RossFast or MODFLOW performance/accuracy remains owned by their separate papers.

## 8. Publication feasibility assessment after the initial pass

Current assessment: **scientifically plausible but not yet secured**.

Reasons for optimism:

- no reviewed source yet combines the full candidate state-authority plus evidence-evolution pattern in a mature process-based environmental model;
- SWAP5 has unusually deep longitudinal evidence, including rejected-transaction tests and real evidence-preservation failures/successors, which can support empirical rather than rhetorical claims;
- the broader PhD arc gives a meaningful downstream test of whether the preservation framework actually enables solver substitution and coupling.

Main threats:

- the paper can easily collapse into a development narrative;
- Noah-MP and SUMMA already occupy much of the architecture/refactoring territory;
- generic change-impact and assurance-case literature may substantially reduce the novelty of the evidence-preservation claim;
- one deep SWAP case cannot prove universality;
- governance machinery is not a scientific result unless measurable consequences are demonstrated;
- terminology such as `scientific authority` can sound invented unless operationally defined and tied to falsifiable tests.

## 9. Introduction argument, preliminary form

A defensible introduction could develop the argument in this order:

1. Mature process-based models are executable scientific knowledge and often evolve for decades; changes to implementation can affect reproducibility and credibility even when scientific equations are intended to remain unchanged.
2. The community has already developed strong responses: modular refactoring and modern interfaces (Noah-MP, SUMMA, BMI/OpenMI), sustainable rewrites and FAIR practices (WaterGAP, FAIR4RS), and continuous/regression testing of scientific software (Farrell; Kanewala and Bieman; SWMM).
3. Numerical libraries and co-simulation frameworks also already support rejected steps, retry and rollback. Generic software engineering provides change-impact analysis and evolving assurance evidence.
4. These advances solve important parts of the problem but are usually treated separately. A remaining question is how, during the staged replacement of a mature time-stepped scientific implementation, to define which computed state is scientifically authoritative and how the evidence supporting that authority evolves with the code.
5. `PUB-ME` should test a concrete method that combines explicit accepted/candidate state semantics with evidence-gated staged migration, using SWAP 4.3.1 to SWAP5 as a deep longitudinal case.
6. The contribution should be stated as a transferable pattern supported by one detailed case, with explicit limits, rather than a universal software architecture theorem.

## 10. Evidence still needed before a strong paper claim

Minimum evidence beyond architecture description:

- representative hydrologic preservation matrix, including trajectories and integrated balances;
- restart/split-run consistency on accepted state;
- adversarial rejected-trial case showing no leakage into committed state or accepted accounting;
- at least one plausible contamination path that the explicit authority boundary prevents or detects;
- longitudinal examples where prior evidence was legitimately reused;
- longitudinal examples where prior evidence was correctly invalidated or replaced by a semantic successor;
- measurement of the practical qualification burden, for example how much of the evidence graph needs replay after different classes of change;
- explicit negative examples where the method provides no advantage or becomes too costly;
- downstream demonstration that a later solver/coupling route can attach without changing the preserved reference denominator, without importing those later papers' primary results.

## 11. Search clusters for the next review pass

The next pass must deliberately search for work most capable of falsifying the candidate gap:

1. transactional or speculative state semantics in scientific simulation frameworks;
2. adaptive integration libraries with explicit accepted-state checkpoint/retry contracts;
3. FMI/co-simulation rollback and state serialization;
4. scientific-workflow provenance under software evolution;
5. semantic regression and change-impact analysis for numerical/scientific software;
6. evolving assurance/safety cases and evidence invalidation;
7. formal equivalence checking during legacy software replacement;
8. Earth-system, climate, land-surface and hydrological model modernization beyond Noah-MP, SUMMA and WaterGAP;
9. reproducibility and verification frameworks that distinguish model state/trajectory semantics from artifact reproducibility;
10. empirical studies on the cost and effectiveness of selective requalification.

## 12. Search log, initial targeted pass

Search date: 2026-09-18.

Initial query families included combinations of:

- legacy scientific software modernization / hydrological reprogramming / model refactoring;
- behavior-preserving refactoring / numerical equivalence;
- scientific software testing / regression testing / continuous verification;
- hydrologic model modularity / interoperability / BMI / OpenMI;
- timestep rejection / retry / rollback / accepted state / candidate state;
- FMI co-simulation rollback / state save and restore;
- scientific software provenance / evolution / verification;
- change impact analysis / regression test selection / assurance evidence evolution.

This is a targeted novelty scan, not yet a systematic review. Search strings, inclusion/exclusion criteria, database coverage and citation chasing must be formalized before the manuscript makes a literature-completeness claim.

## 13. Working decision

Do **not** yet write the paper around "modernizing SWAP while preserving results".

Continue only if the next literature pass fails to find a close prior method for the combined problem of:

> accepted scientific state authority + speculative/rejected execution + staged semantic migration + change-aware scientific qualification evidence.

If such a method is found, narrow `PUB-ME` further or absorb the modernization work as thesis context rather than protecting a weak standalone publication.