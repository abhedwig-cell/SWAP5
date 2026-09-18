# PUB-ME literature review pass 6: novelty closure and citation chase

Status: **LITERATURE_GAP_REMAINS_OPEN_BUT_PRIORITY_NOT_PROVEN**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Review date: 2026-09-18

## 1. Purpose

This pass closes the current G5 literature obligation for the post-D1-D6 publication decision.

It does **not** attempt to prove universal novelty. It asks a narrower falsification question:

> Has peer-reviewed prior work already evaluated, during modernization of a mature scientific/process simulator, whether explicit authority at the candidate-to-accepted state boundary provides incremental qualification value against a strong scientific-software baseline across multiple side channels such as state, accounting, restart, numerical workspace, and external publication?

A close positive match would materially weaken or remove the current standalone PUB-ME claim.

## 2. Review boundary

This is a targeted adversarial scoping/citation-chasing pass, not a claim of exhaustive systematic-review coverage.

Search channels used in the current closure included:

- publisher/journal search results and primary article pages;
- scholarly web search over exact concept combinations;
- backward/forward conceptual citation chasing from the closest modernization, simulation rollback, assurance, and reproducibility anchors;
- recent 2025-2026 hydrologic, Earth-system, HPC and scientific-software modernization literature;
- emerging preprints tracked separately from peer-reviewed authority.

Concept clusters included:

- legacy scientific software modernization / reengineering;
- hydrologic and Earth-system model refactoring;
- scientific software preservation / equivalence;
- candidate, accepted, committed, speculative and rollback state;
- rejected-step side effects and output commit;
- restart/persistence authority;
- numerical workspace versus physical state;
- fault injection and semantic mutation;
- scientific-software assurance cases;
- evidence evolution / change impact;
- ongoing and statistical model reproducibility.

Searches were deliberately repeated with `scientific software`, `simulation`, `hydrologic`, `Earth system`, `legacy Fortran`, `process model`, and `modernization` terminology because the relevant communities use different vocabulary.

## 3. Highest-risk established prior art

### 3.1 Hydrologic and land-model modernization

#### He et al. (2023), Noah-MP v5

Geoscientific Model Development 16, 5131-5151.
DOI: 10.5194/gmd-16-5131-2023.

Establishes:

- whole-model refactoring without intended physics change;
- modern Fortran and hierarchical data structures;
- process-level modularization;
- improved driver/coupling interfaces;
- benchmark/reference datasets;
- transferability claims to other land/Earth-system models.

Novelty impact:

- removes modernization, modularity, coupling-readiness, modern data structures and preserved-output benchmarking as PUB-ME novelty.

Does not establish from reviewed material:

- a prospective multi-defect comparison of candidate-to-accepted authority against a strong scientific-software baseline.

#### Nyenah et al. (2025), WaterGAP

Geoscientific Model Development 18, 5635-5653.
DOI: 10.5194/gmd-18-5635-2025.

Establishes:

- reprogramming a mature global hydrological model as a research-software contribution;
- modularization, automation, documentation, FAIR/sustainability and quality control.

Peer-review relevance:

- reviewer discussion explicitly challenged the scientific merit/novelty when the work read primarily as a development/reprogramming narrative.

Novelty impact:

- PUB-ME cannot be justified merely because SWAP5 is a deep and valuable modernization.

#### Trim et al. (2025), SUMMA

Environmental Modelling & Software 194, 106668.
DOI: 10.1016/j.envsoft.2025.106668.

Establishes:

- a general hierarchical architecture for process-based hydrologic models;
- composable components;
- initialize-update-finalize;
- numerical/physical separation;
- interoperability and extensibility;
- behavior-preserving refactoring.

Novelty impact:

- removes modular architecture, component composition and numerical/physics separation as standalone PUB-ME claims.

### 3.2 Ongoing scientific reproducibility during code change

#### Mahajan et al. (2019), E3SM

International Journal of High Performance Computing Applications 33(5).
DOI: 10.1177/1094342019837341.

Establishes:

- an explicit methodology for ongoing solution reproducibility while E3SM software infrastructure evolves.

#### Mahajan et al. (2026), enhanced climate reproducibility testing

Earth System Dynamics 17, 23-?.
Peer-reviewed 2026 work extends ensemble/statistical reproducibility testing for E3SM with false-discovery-rate control.

Novelty impact:

- repeated scientific preservation tests across software/infrastructure evolution are established prior art;
- PUB-ME cannot claim novelty for continuous or statistically qualified equivalence testing.

### 3.3 Scientific-software engineering best practice

#### Gregor et al. (2026)

*Best practices in software development for robust and reproducible geoscientific models based on insights from the Global Carbon Budget's dynamic vegetation models*.
Geoscientific Model Development 19, 2407-2436.
DOI: 10.5194/gmd-19-2407-2026.

Establishes a current community-level synthesis of:

- testing;
- version control;
- CI;
- documentation;
- maintainability;
- reproducible workflows;
- software quality practices for geoscientific models.

Novelty impact:

- generic best-practice/governance claims are especially weak in 2026.

### 3.4 Speculative state, rollback, commit and irreversible output

#### Time Warp / optimistic simulation literature

Established literature already treats:

- speculative/provisional simulation history;
- checkpointing and state recovery;
- rollback and re-execution;
- eventual commitment.

#### Antonacci, Pellegrini and Quaglia (2013)

*Consistent and efficient output-streams management in optimistic simulation platforms*.
ACM SIGSIM PADS 2013, 315-326.
DOI: 10.1145/2486092.2486133.

Especially important for D6.

Establishes:

- external output is a known rollback problem because the outside world may not support rollback;
- output from speculative execution should become visible consistently with eventually committed events.

Novelty impact:

- accepted-only external publication is not a new PUB-ME mechanism;
- D6 is an empirical modernization-qualification result, not a new output-commit principle.

### 3.5 Assurance and evidence evolution

#### Smith, Sayari Nejad and Wassyng (2021)

*Raising the Bar: Assurance Cases for Scientific Software*.
Computing in Science & Engineering 23(1), 47-57.
DOI: 10.1109/MCSE.2020.3019770.

Establishes:

- explicit claim-evidence correctness arguments applied directly to scientific software.

#### Wei et al. (2024), ACCESS

*ACCESS: Assurance Case Centric Engineering of Safety-critical Systems*.
Journal of Systems and Software 213, 112034.
DOI: 10.1016/j.jss.2024.112034.

Establishes:

- evolving model-based assurance cases;
- traceability to engineering artifacts;
- automated assurance evaluation;
- change-impact analysis from changed engineering artifacts to assurance claims/evidence.

Novelty impact:

- claim-evidence graphs, evidence evolution and selective reevaluation are not generically new;
- PUB-ME RQ1b can only be secondary if scientific transition semantics produce a demonstrable distinction from generic assurance/change-impact practice.

## 4. New 2026 modernization comparators identified in closure

These sources materially raise the state-of-the-art bar but do not, from the reviewed material, close the remaining transition-authority gap.

### 4.1 Baikal-GVD legacy scientific software reengineering

Solovjev et al. (2026), *Reengineering of the cascade reconstruction in the Baikal-GVD experiment: principles of working with legacy scientific software*.

The study describes stepwise manual translation of legacy Fortran into a modern C++ framework, verification at each stage, conversion of common blocks into modern data containers, process/task modularization, and preservation of physical validity.

Novelty impact:

- another direct 2026 scientific-software precedent for staged verified reengineering;
- further weakens any narrative based on incremental translation plus physical-validity preservation.

No reviewed indication was found of a D1-D6-like candidate/accepted authority study.

### 4.2 MESMER v1 sustainable Earth-system research software

Bauer et al. (2026), *MESMER v1.0.0: consolidating the modular Earth system model emulator into a sustainable research software package*.
Geoscientific Model Development 19, 5669-?.

The redesign is assessed against modularity, modern data structures, documentation, testing, version control and CI, with saved reference test data used to detect unintended change.

Novelty impact:

- sustainable scientific-software redesign plus regression/reference testing remains active peer-reviewed practice;
- not a close comparator for transition-authority fault localization.

### 4.3 NextGen Water Resources Modeling Framework

Ogden et al. (2026), *The NextGen Water Resources Modeling Framework: Community Innovation at the Intersection of Hydrologic, Data and Computer Sciences*.

Provides current hydrologic context for moving from tightly coupled legacy code toward model-agnostic modular/interoperable frameworks.

Novelty impact:

- reinforces that modularity, refactoring and interface products are established hydrologic modernization directions;
- does not provide the targeted candidate-to-accepted authority experiment.

### 4.4 Current climate-model reproducibility

Mahajan et al. (2026) extend E3SM statistical reproducibility testing.

Novelty impact:

- the scientific preservation comparator must be stronger than deterministic regression alone;
- where exact equality is inappropriate, scientifically justified statistical equivalence is already established methodology.

## 5. Emerging work that raises priority risk

Emerging/preprint work is tracked separately and is **not** treated as equivalent to peer-reviewed authority.

### Coleman et al. (2026), GAMESS differential fault injection

arXiv:2608.14527.

Applies identical deterministic faults to original and modernized scientific kernels and compares off-nominal behavior over more than 2,200 runs.

Priority impact:

- generic fault injection or off-nominal modernization fidelity cannot carry PUB-ME novelty;
- by manuscript submission, publication status must be rechecked.

### Shen et al. (2026), agentic GAMESS modernization

arXiv:2608.12249.

Uses a canonical domain test suite as an exact merge oracle during modernization of mature quantum-chemistry Fortran.

Priority impact:

- canonical legacy-reference gating during modernization is increasingly explicit recent practice.

### Hoshino et al. (2026), CReSS validation-centric GPU porting

arXiv:2608.13122.

Uses physically meaningful runtime-state dumps, element-wise kernel validation and whole-application validation while porting a 250,000+ line weather model.

Priority impact:

- validation-centric modernization of large scientific simulators is an active 2026 research frontier;
- PUB-ME must retain its narrower causal transition-authority contribution if these works become peer reviewed.

### Li et al. (2026), semantic mutation for scientific computing

arXiv:2605.17437.

Develops domain-semantic mutation operators and adequacy analysis for scientific computing.

Priority impact:

- semantic mutants themselves cannot be presented as novel methodology in PUB-ME.

## 6. Citation-chase result

The closure search deliberately tried to find a peer-reviewed work satisfying the following close-comparator profile:

1. mature scientific/process simulator undergoing architectural modernization;
2. frozen legacy scientific denominator;
3. strong comparator that already includes regression, invariants, restart and normal scientific-software testing;
4. explicit candidate/speculative versus accepted/committed scientific-state authority;
5. prospective or otherwise clearly designed contamination faults;
6. multiple consequence channels, not only physical state:
   - accepted accounting;
   - persistence/restart;
   - numerical workspace/continuation;
   - external publication;
7. comparative result stated as earlier/localized detection or structural prevention at the authority boundary;
8. longitudinal use during migration rather than a standalone numerical integrator or optimistic-simulation mechanism study.

**No close peer-reviewed match was identified in this targeted pass.**

This is a bounded negative search result.

It is **not** evidence that no such work exists, and it does not authorize wording such as:

- first;
- unique;
- unprecedented;
- no prior work.

## 7. Final novelty boundary after D1-D6 and Pass 6

### Mechanisms that are prior art

Do not claim novelty for:

- behavior-preserving refactoring;
- modern scientific-software architecture;
- modularity/interoperability;
- accepted/rejected timesteps;
- speculative versus committed state;
- checkpoint/restore;
- rollback/retry;
- transaction semantics;
- accepted-only external output;
- regression/metamorphic/mutation/fault-injection testing;
- ongoing solution reproducibility;
- claim-evidence assurance cases;
- dependency/change-impact analysis;
- staged legacy modernization.

### Candidate empirical contribution that remains defensible

The surviving contribution is an **application and evaluation claim**:

> During staged modernization of a mature stateful process model, explicit transition-authority contracts can localize or structurally prevent selected contamination of accepted scientific history at the point where non-authoritative computation attempts to cross into accepted state, accounting, persistence, numerical continuation, or external publication.

This claim must remain bounded by the actual D1-D6 evidence:

- D1: STRUCTURAL_PREVENTION;
- D2: EARLIER_DETECTION;
- D3: STRUCTURAL_PREVENTION;
- D4: EARLIER_DETECTION;
- D5: EARLIER_DETECTION;
- D6: EARLIER_DETECTION;
- no UNIQUE_DETECTION.

The paper therefore must **not** claim higher ultimate fault coverage than the strong B1 comparator.

Its empirical distinction is:

- earlier causal localization; and
- structural prevention at authority boundaries.

## 8. Safe novelty wording

Subject to final manuscript-date update, a bounded formulation is:

> Prior studies have separately established behavior-preserving scientific-model modernization, scientific-software verification and reproducibility, rollback-capable simulation, and change-aware assurance. We evaluate whether making the candidate-to-accepted scientific-state transition an explicit qualification target provides measurable causal-localization and structural-prevention value during modernization of a mature process-based environmental model.

A stronger but still bounded result sentence, if replication/preservation gates remain positive, could be:

> Across preregistered authority-boundary defect families, the explicit transition contracts did not increase ultimate defect coverage relative to the strong comparator, but they either made selected invalid transitions structurally unrepresentable or exposed contamination before it propagated into downstream accounting, restart, numerical continuation, or external publication checks.

## 9. Prohibited priority wording

Until an independently reproducible database-level systematic review is completed, do not write:

- `for the first time`;
- `the first framework`;
- `unique`;
- `unprecedented`;
- `no previous work`;
- `we introduce transactional scientific modelling`;
- `we introduce accepted/rejected state semantics`;
- `existing testing cannot detect these faults`.

## 10. G5 decision

Verdict:

**G5_TARGETED_LITERATURE_CLOSURE_PASS__NO_CLOSE_COMPARATOR_FOUND__PRIORITY_NOT_PROVEN**

Meaning:

- the standalone PUB-ME line survives the current novelty challenge;
- mechanism novelty is explicitly rejected;
- publication novelty, if retained, is the bounded empirical evaluation during scientific-model modernization;
- priority language remains conservative;
- literature must be refreshed immediately before manuscript submission because 2026 scientific-software modernization work is moving rapidly.

## 11. Remaining paper-readiness dependencies outside G5

G5 closure does not make PUB-ME manuscript-ready.

The post-D1-D6 go/no-go still depends on the non-literature evidence gates already registered in the publication programme, including:

- representative preservation of the declared SWAP scientific denominator;
- production checkpoint/run/restore/rerun identity;
- legitimate warm-start invariance;
- hydrologic-regime replication of selected authority consequences;
- successful reconciliation of any later dependency-changing semantic successor evidence.

G5 must not be used to rescue a paper if those empirical preservation/replication gates fail.

## 12. Literature refresh trigger

Re-open the novelty search before submission if any of the following occurs:

- GAMESS/CReSS modernization preprints become peer reviewed;
- new hydrologic or Earth-system modernization papers cite Noah-MP, SUMMA, WaterGAP, MESMER or NextGen while adding fault/adversarial qualification;
- a scientific-software assurance study combines runtime state authority with modernization;
- a reviewer identifies a close candidate-to-accepted authority comparator;
- more than three months elapse before manuscript submission.

