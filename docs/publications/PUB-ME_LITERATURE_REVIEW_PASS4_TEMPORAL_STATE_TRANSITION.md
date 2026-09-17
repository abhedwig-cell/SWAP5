# PUB-ME literature review pass 4: temporal/state-transition correctness

Status: **targeted adversarial novelty review**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Review date: 2026-09-18

## 1. Purpose

This pass tests the narrowest remaining candidate novelty after the earlier review removed broader claims around refactoring, modularity, rollback, continuous verification, regression testing, mutation testing and change-impact analysis.

The search question is:

> Has prior peer-reviewed work already made candidate-to-accepted state-transition correctness, and contamination of accepted scientific history by rejected/retried computation, the central empirical discriminator in modernization of a mature time-stepped process model?

This is deliberately narrower than asking whether rollback, rejected timesteps, restart or state save/restore exist. Those mechanisms are established prior art.

## 2. Search clusters

Queries were organized around combinations of:

- accepted state / current state / committed state;
- candidate / provisional / speculative state;
- rejected step / failed timestep / retry;
- rollback / checkpoint / restart;
- event side effects after rejected steps;
- state contamination / history contamination;
- restart consistency;
- numerical simulation / scientific software / hydrology / geoscience;
- semantic mutation / state-transition mutation;
- change-impact / assurance evidence evolution.

Searches crossed numerical analysis, scientific software, co-simulation, simulation infrastructure, hydrologic/environmental models, Earth-system modelling and software-assurance research.

## 3. Findings that further narrow PUB-ME

### 3.1 Accepted/rejected timestep lifecycle is mature numerical practice

PETSc TS explicitly distinguishes successful steps from rolled-back steps and provides lifecycle callbacks whose semantics depend on whether rollback occurred. Sandia's Aria likewise treats a failed nonlinear timestep as non-advancing and retries with a reduced timestep.

Consequence:

- PUB-ME cannot claim novelty for the rule that failed or rejected steps must not advance accepted numerical time;
- callback ordering around rollback is already treated as a meaningful correctness concern in mature numerical infrastructure;
- a SWAP5 transaction diagram is therefore explanatory infrastructure, not a novel scientific result.

### 3.2 Rollback and state restoration are mature in co-simulation

FMI/co-simulation literature and libraries already use state save/restore to repeat communication intervals, support event localization, or adapt macro-step size. Recent co-simulation work still treats rollback support as a major subsystem capability.

Consequence:

- state checkpoint/restore, speculative interval evaluation and re-execution are prior art;
- PUB-ME novelty cannot rest on making a process model rollback-capable.

### 3.3 Restart correctness is an established simulator requirement

Scientific simulation frameworks commonly define restart as continuation from a stored internal state. Mature documentation emphasizes that restart files must capture enough model/integrator state for continuation, and that changing parameters across restart can alter semantics.

Consequence:

- restart/split-run equivalence is an established verification target;
- the potential contribution is narrower: preventing a restart artifact from being created from a trial that never became scientifically accepted.

### 3.4 Scientific software testing already goes beyond successful-run regression

SWMM studies characterize thousands of unit tests and numerical regression tests, and related work combines regression, metamorphic testing and mutation analysis. Earlier scientific-software research also evaluates mutation-sensitivity testing for silent faults. Recent semantic-mutation work explicitly targets domain-semantic faults such as conservation erosion and trajectory changes.

Consequence:

- `regression tests can miss bugs` is not a novel finding;
- adversarial/fault-injection experiments are not novel by themselves;
- PUB-ME needs a defect class tied specifically to authority of state transitions, not merely more sophisticated tests.

### 3.5 Geoscientific model communities already study ongoing reproducibility under software evolution

E3SM work establishes ongoing solution reproducibility during infrastructure/compiler/library evolution where no intentional science change is intended. Newer geoscientific best-practice literature explicitly promotes testing, validation, CI, code review, documentation and reproducible workflows across state-of-the-art Earth-system/land-surface models.

Consequence:

- maintaining scientific reproducibility while infrastructure changes is established prior art;
- PUB-ME must not frame continuous preservation across modernization as the central novelty.

### 3.6 Claim-evidence evolution is already mature in assurance engineering

ACCESS and related assurance-case work explicitly links claims to engineering artifacts, evaluates the impact of artifact changes on assurance cases, and supports re-evaluation as systems evolve. Change-impact analysis and regression-test selection are mature fields, including formalized dependency-graph approaches.

Consequence:

- `evidence changes when software changes` is not novel;
- the PUB-ME evidence layer can only remain a contribution if scientific state-transition semantics lead to materially different requalification decisions than generic code/test dependency analysis.

## 4. Plausibility evidence for the remaining defect class

A real numerical-software issue was found in Diffrax in which a terminating event could fire on a timestep that was subsequently rejected. This is not peer-reviewed evidence and must not be used as a novelty source. It is nevertheless a useful plausibility example: side effects can escape an accepted/rejected-step boundary in production numerical software.

The important manuscript distinction is therefore not that rejected-step contamination can occur in principle. The scientific question is whether explicit transition-authority contracts provide measurable additional protection during architectural modernization of a mature process model.

## 5. Bounded negative search result

This pass did not identify a close peer-reviewed study with all of the following as one empirical modernization design:

1. a mature process-based scientific model is being architecturally replaced or decomposed;
2. a strong conventional scientific-software qualification baseline is retained;
3. explicit candidate-to-accepted state-transition authority is added as a separate semantic contract;
4. preregistered defects specifically target contamination of accepted model history by rejected/retried work;
5. the incremental defect-detection or prevention value of the transition contract is measured against the strong baseline;
6. the same semantic boundary is then used to reason about which prior scientific evidence remains valid after later changes.

This is a bounded search result, not a priority claim. Absence of an identified close comparator does not prove novelty.

## 6. Recommended research-question split

### Primary RQ1a

> **During staged modernization of a mature time-stepped process model, do explicit transition-authority contracts at the candidate-to-accepted state boundary provide incremental protection against scientifically consequential contamination faults beyond a strong baseline of established scientific-software testing?**

### Secondary RQ1b

> **Can those scientific transition semantics guide selective requalification after later software changes without reducing coverage of scientifically relevant impacts?**

The primary question should carry the paper. The evidence/requalification question is secondary because generic evidence-evolution prior art is much stronger.

## 7. Meaning of `transition-authority contract`

This is a working operational term, not a claimed established field term and not itself a novelty claim.

A transition-authority contract specifies at minimum:

- the authoritative accepted origin state;
- the identity and interval of a candidate computation;
- which mutations are provisional until acceptance;
- what must be discarded on rejection;
- which accounting, restart and external-publication effects may occur only after acceptance;
- conditions under which a candidate may be committed;
- which numerical workspace is explicitly non-authoritative.

The term should be abandoned if it does not improve precision relative to established terminology.

## 8. Strong comparator required by the literature

The comparison may not use a weak `output regression only` baseline.

The conventional baseline must contain, where applicable:

- frozen reference-output regression;
- physical/domain invariants such as mass conservation;
- unit and integration tests;
- restart/split-run tests;
- accepted/rejected timestep checks already expected by normal numerical practice;
- mutation/metamorphic or equivalent semantic checks for the chosen defect domain where credible;
- continuous CI/reproducibility practice.

The candidate treatment adds explicit transition-authority oracles at the speculative-to-accepted boundary.

If these oracles do not provide measurable incremental coverage, the primary hypothesis is weakened or rejected.

## 9. Novelty claims removed by pass 4

Do not claim novelty for:

- accepted versus rejected timesteps as a numerical concept;
- rollback/checkpoint/restore;
- restart equivalence;
- event handling around rollback in general;
- scientific mutation or metamorphic testing;
- ongoing solution reproducibility under code/infrastructure change;
- CI and geoscientific software best practices;
- change-aware claim/evidence graphs or assurance-case re-evaluation in general.

## 10. Remaining defensible candidate contribution

The narrow candidate contribution is an **empirical modernization study** of whether explicit scientific transition-authority contracts add fault-detection/prevention value for a preregistered class of state-history contamination defects, when compared against a strong existing scientific-software testing baseline, and whether those semantics subsequently help bound requalification.

The contribution is the demonstrated incremental scientific value, if any. It is not the architecture pattern alone.

## 11. Literature anchors added in this pass

Peer-reviewed / close or adjacent:

- Mahajan et al. (2019), *Ongoing solution reproducibility of earth system models as they progress toward exascale computing*, International Journal of High Performance Computing Applications, 33(5), 784-790, DOI 10.1177/1094342019837341.
- Gregor et al. (2026), *Best practices in software development for robust and reproducible geoscientific models based on insights from the Global Carbon Budget's dynamic vegetation models*, Geoscientific Model Development, 19, 2407-2436, DOI 10.5194/gmd-19-2407-2026.
- Peng et al. (2021), *Unit and regression tests of scientific software: A study on SWMM*, Journal of Computational Science, 53, 101347, DOI 10.1016/j.jocs.2021.101347.
- Investigating test selection techniques for scientific software using Hook's mutation sensitivity testing (2010), Procedia Computer Science 1(1), 1487-1494, DOI 10.1016/j.procs.2010.04.165.
- Clark, Dan and Hierons (2013), *Semantic mutation testing*, Science of Computer Programming, 78(4), 345-363, DOI 10.1016/j.scico.2011.03.011.
- ACCESS: Assurance Case Centric Engineering of Safety-critical Systems (2024), Journal of Systems and Software, DOI 10.1016/j.jss.2024.112034.
- Palmskog, Celik and Gligoric (2020), *Practical Machine-Checked Formalization of Change Impact Analysis*, TACAS 2020.

Mature technical infrastructure / adjacent practice:

- PETSc TS rollback and post-evaluate lifecycle documentation.
- Sandia Aria timestep-failure semantics.
- FMI/FMI++ rollback/state-save interfaces and co-simulation literature.

Emerging/non-peer-reviewed leads, tracked separately:

- Diffrax issue #464, event activation on a rejected step, used only as plausibility evidence.
- 2026 semantic-mutation preprints for scientific computing, used as priority-risk evidence until peer-review status is established.

## 12. Current adjudication

**PUB-ME remains scientifically plausible, but only under the narrower RQ1a/RQ1b framing.**

The decisive next step is no longer another architecture diagram or broad preservation benchmark. It is a preregistered comparative D1-D6 experiment in which the strong conventional baseline is given every reasonable advantage and the transition-authority layer must demonstrate incremental value.
