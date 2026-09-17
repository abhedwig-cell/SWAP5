# Prospective PhD research programme

Status: **living research-programme hypothesis**

This document places the SWAP5 publication portfolio inside a possible doctoral research programme. It is not a formal university PhD proposal, enrolment statement or degree claim. Its purpose is to make the developing research coherent enough that a formal proposal can later be derived from evidence rather than reconstructed retrospectively.

## 1. Working doctoral theme

### Short working title

**Trustworthy evolution of process-based scientific models**

### More specific working title

**Preserving scientific validity while evolving process-based hydrological models into qualifiable and composable simulation systems**

SWAP5 is the principal research object and demonstrator, but the intended contribution should not reduce to "development of a new SWAP version". The doctoral contribution should extract methods and evidence that are useful beyond SWAP itself.

## 2. Overarching research question

> How can an established process-based environmental model be fundamentally evolved, numerically extended and coupled to other dynamic models while preserving scientific validity, traceability and reproducibility?

This question deliberately spans scientific software evolution, numerical qualification and multiphysics coupling, but it must remain anchored in one coherent methodological problem: **how scientific meaning is preserved while the executable model becomes more replaceable, composable and extensible**.

## 3. Provisional central thesis

The provisional thesis to be tested across the programme is:

> Scientific model evolution becomes more trustworthy when scientific state, candidate execution, acceptance, numerical substitution and inter-model exchange are made explicit and independently qualifiable. These separations can preserve legacy scientific behaviour while enabling new solvers and conservative coupling without surrendering reproducibility or evidential traceability.

This statement is a research hypothesis, not an admitted conclusion. It may be narrowed, contradicted or reformulated by the individual studies.

## 4. Research architecture

The programme is no longer treated as a strict five-step chain. The current dependency structure is:

```text
                    -> REPLACE
PRESERVE -----------|
                    -> COUPLE -> ACCELERATE
                              \
                               -> SCALE
```

The steps mean:

- **PRESERVE**: test whether explicit scientific-state authority provides measurable protection against semantic contamination during modernization;
- **REPLACE**: test prospective scientific admission of a numerically distinct Richards solver without changing the surrounding scientific lifecycle;
- **COUPLE**: determine the finite-window contract required to compose independently time-integrating vadose-zone and groundwater models conservatively and reproducibly;
- **ACCELERATE**: conditionally test whether additional whole-window response information improves coupling beyond strong generic black-box acceleration;
- **SCALE**: conditionally test when an equivalent single vadose-zone column loses transferability across hydrologic regimes.

`REPLACE` is not a prerequisite for `COUPLE`; the coupling study may use the qualified Reference Richards solver. `ACCELERATE` depends on a stable `COUPLE` method and may collapse into that paper if no independent response-information result exists. `SCALE` depends on conservative N:1 coupling semantics but not on `ACCELERATE`.

## 5. Research questions and publication mapping

| Research question | Publication owner | Role in thesis |
| --- | --- | --- |
| RQ1. Which scientifically relevant state-contamination faults can escape conventional regression and invariant testing during staged modernization, and to what extent does explicit candidate-to-accepted state authority prevent or expose them? | `PUB-ME` | tests scientific-state authority as a causal fault-containment mechanism |
| RQ2. Under what operating conditions can a numerically distinct Richards solver be admitted as scientifically interchangeable when admission is defined prospectively by trajectory, conservation, robustness and computational criteria? | `PUB-SQ` | tests qualified numerical substitution and its domain of validity |
| RQ3. What coupling contract is sufficient for conservative and convergent partitioned simulation of dynamically interacting vadose-zone and groundwater models when both retain independent internal time integration? | `PUB-GC` | tests composability, whole-window exchange and accepted-state coupling semantics |
| RQ4. What is the lowest-order hydrologically meaningful whole-window response information that materially improves robust coupling convergence beyond generic black-box acceleration? | `PUB-RC`, conditional | tests the incremental value of hydrologic interface information |
| RQ5. Under which combinations of vadose-zone heterogeneity, atmospheric forcing and groundwater dynamics does an equivalent single-column representation cease to be transferable across hydrologic regimes? | `PUB-SG`, conditional | tests spatial representativeness and aggregation limits |

## 6. Minimum viable thesis

The research programme must not depend on all five proposed papers succeeding.

The non-negotiable scientific spine is provisionally:

1. `PUB-ME`, if the causal state-authority hypothesis survives;
2. `PUB-SQ`, if a defensible solver-admission domain can be demonstrated;
3. `PUB-GC`, as the principal composition/coupling study.

At least one additional independent study or synthesis-level contribution is then required for a robust article-based doctoral body, subject to institutional rules.

`PUB-RC` is explicitly conditional. It becomes a standalone paper only if hydrologically meaningful response information adds reproducible value beyond strong generic black-box acceleration at matched coupled error.

`PUB-SG` is also conditional, but for a different reason. It becomes a standalone paper only if cross-regime transferability of an equivalent column reveals a distinct and generalizable hydrologic result after coupling and solver error have been separated.

Failure of either conditional hypothesis is evidence and must not be hidden or repaired by creating a paper around infrastructure alone.

## 7. Paper-to-thesis firewall

The publication portfolio retains single ownership of primary scientific claims. The thesis may synthesize those findings, but may not retroactively blur their provenance.

The thesis synthesis may:

- compare conclusions across publications;
- identify common mechanisms that only become visible across multiple studies;
- generalize from SWAP-specific evidence to a broader class of scientific models, with explicit limits;
- discuss failed hypotheses and design choices omitted from journal-length papers;
- connect software architecture, numerical analysis and hydrological implications.

The thesis synthesis must not:

- present the same primary result as if independently discovered in multiple papers;
- inflate an infrastructure contribution into a second scientific result;
- turn a post-hoc observation into a pre-specified hypothesis without preserving the chronology;
- hide negative experiments that materially affect the general thesis.

## 8. Thesis-only synthesis claims

Some claims may be legitimate only after multiple studies have been completed. These should be registered as `THESIS-SYNTHESIS` rather than assigned prematurely to one paper.

Candidate synthesis hypotheses include:

### TS1. Explicit acceptance is a scientific boundary

Candidate hypothesis:

> Distinguishing computed candidate state from accepted scientific state is not only a software-engineering device; it provides a common mechanism for reproducible timestep retry, solver substitution and inter-model coupling.

Potential supporting studies: `PUB-ME`, `PUB-SQ`, `PUB-GC`.

### TS2. Scientific modularity requires qualification, not only interfaces

Candidate hypothesis:

> A process model becomes scientifically composable only when interfaces are accompanied by explicit state ownership, units, temporal semantics, acceptance rules and qualification evidence.

Potential supporting studies: `PUB-ME`, `PUB-SQ`, `PUB-GC`.

### TS3. Reproducible subsystem evaluation enables higher-order coupling methods

Candidate hypothesis:

> Response-based or quasi-Newton coupling is scientifically meaningful only when each subsystem response is evaluated from a well-defined and reproducible accepted origin.

Potential supporting studies: `PUB-GC`, `PUB-RC`.

### TS4. Structural modernization can create scientific experimental capability

Candidate hypothesis:

> Behaviour-preserving modernization can be scientifically productive even before new process physics are introduced, because it makes controlled numerical substitution, coupling and falsifiable experimentation possible.

Potential supporting studies: all core papers.

None of these are admitted conclusions at programme start.

## 9. Contribution layers

The prospective thesis should distinguish at least four contribution layers.

### A. Hydrological/scientific-model contribution

Evidence about preservation of process-model behaviour and groundwater-vadose interaction.

### B. Numerical-method contribution

Solver qualification, coupling convergence, conservation, response information and error-versus-cost behaviour.

### C. Scientific-software methodology contribution

State ownership, transactional candidate/accepted separation, migration and qualification patterns insofar as they have demonstrated consequences for scientific validity.

### D. Research-method contribution

Prospective traceability from hypothesis through code, qualification, experiment, result, publication and synthesis.

Layer D should support the thesis but should not be overstated as a research result unless independently studied and evaluated.

## 10. Evidence graph

The programme should preserve the following traceability chain:

```text
research question
    -> hypothesis
    -> prior-work boundary
    -> experiment design
    -> source/configuration/input authority
    -> qualification evidence
    -> immutable run/result artifact
    -> derived figure/table
    -> paper claim
    -> thesis synthesis claim
```

Each transition should be recoverable from repository records or frozen research artifacts.

## 11. Prospective evidence metadata

Publication-relevant evidence should additionally allow thesis-level registration:

```yaml
research_relevance:
  phd_rq:
    - RQ1
  publication_primary: PUB-ME
  thesis_synthesis_candidates:
    - TS1
  hypothesis_status: proposed | tested | supported | weakened | rejected
  pre_result_design_reference: <commit/document/id>
  evidence:
    - <immutable evidence reference>
  negative_evidence:
    - <reference or null>
  reuse_constraints:
    - <publication/thesis boundary>
```

The exact serialization format may change. The required information should not.

## 12. Chronology protection

Because the research programme is being designed while development is in progress, chronology must be preserved explicitly.

For every major hypothesis or experiment, record:

1. when the question was first formalized;
2. which prior evidence already existed at that moment;
3. the experiment design before inspecting the result where practical;
4. subsequent changes and why they were made;
5. null or negative results;
6. the final publication use, if any.

This does not require rigid preregistration of software research. It prevents retrospective reconstruction from making exploratory findings appear confirmatory.

## 13. Negative-result register

A doctoral programme benefits from evidence that narrows claims as much as evidence that supports them.

Maintain a register for findings such as:

- modernization step produced no measurable scientific difference;
- candidate numerical method offered no useful speed or robustness benefit;
- tighter coupling did not materially change the solution in a tested regime;
- explicit N:1 heterogeneity did not outperform an effective representation for the relevant question;
- proposed generalization proved SWAP-specific.

A negative result may close a paper hypothesis while still strengthening the final synthesis by defining the domain of validity.

## 14. Shared literature architecture

The literature programme should have a common backbone rather than five independent searches.

Maintain linked literature clusters for:

- scientific legacy-model modernization and reproducibility;
- verification, validation and qualification of environmental models;
- nonlinear/Richards solver comparison and admissibility;
- partitioned multiphysics and co-simulation;
- groundwater-vadose coupling, including SWAP, SIMGRO, MetaSWAP and HYDRUS-MODFLOW;
- response/Jacobian/quasi-Newton interface methods;
- hydrological upscaling and subgrid heterogeneity.

Each reference may support multiple background sections, but novelty claims must be evaluated separately for each paper.

## 15. Candidate thesis structure

A future article-based thesis could provisionally use:

1. **General introduction**: the scientific problem of evolving executable environmental models without losing scientific authority.
2. **Conceptual framework**: scientific state, candidate execution, acceptance, qualification and composability.
3. **Study I / `PUB-ME`**: controlled model evolution.
4. **Study II / `PUB-SQ`**: qualified numerical substitution.
5. **Study III / `PUB-GC`**: conservative finite-window groundwater coupling.
6. **Study IV / `PUB-RC`**: response-assisted nonlinear coupling, if supported.
7. **Study V / `PUB-SG`**: subgrid/upscaling study, if supported.
8. **Synthesis**: what the studies jointly establish, what remains SWAP-specific, and what may generalize to other process-based models.
9. **Outlook**: implications for future scientific model ecosystems, not a roadmap disguised as a result.

Exact thesis form depends on institutional rules and should not be assumed yet.

## 16. Generalization test

For every thesis-level conclusion, ask:

> Would this conclusion still be meaningful if the model were not called SWAP?

Possible outcome classes:

- **SWAP-specific**: important domain result, but not a general methodological contribution;
- **hydrological-model class**: likely relevant to similar process-based column or catchment models;
- **scientific-software class**: supported beyond the hydrological particulars;
- **unproven generalization**: plausible but not demonstrated and therefore stated as future work.

The thesis must not generalize beyond its evidence.

## 17. Proposal maturation gates

A formal PhD proposal should only be drafted as an institutional proposal after the research programme has passed an initial maturation gate.

Suggested gate:

- [ ] overarching question remains coherent after targeted literature review;
- [ ] `PUB-ME` and `PUB-SQ` each have a defensible independent research contribution;
- [ ] `PUB-GC` novelty survives systematic coupling-literature review;
- [ ] at least one key study has a concrete reproducible experiment design and evidence path;
- [ ] publication overlap matrix is stable enough to demonstrate four independent studies or an equivalent thesis body;
- [ ] likely supervisors/institutional setting can judge the programme against formal doctoral requirements;
- [ ] authorship, data/software release, time allocation and resource feasibility can be discussed explicitly.

These gates are planning aids, not university admission criteria.

## 18. Programme risks

### Risk: thesis too broad

Mitigation: keep one methodological spine, preserving scientific validity through evolution, substitution and coupling. Remove work that does not test that spine.

### Risk: papers overlap

Mitigation: single-owner claim registry and prospective figure/table firewall in `PUBLICATION_PORTFOLIO.md`.

### Risk: software engineering dominates scientific contribution

Mitigation: every architectural claim must connect to observable scientific/numerical consequences or remain implementation context.

### Risk: novelty erodes during literature review

Mitigation: narrow or redirect individual paper claims without protecting a predetermined manuscript count.

### Risk: development history becomes irreproducible

Mitigation: preserve pre-result hypotheses, exact source heads, configurations, qualification evidence and immutable result artifacts.

### Risk: a conditional paper is forced

Mitigation: both `PUB-RC` and `PUB-SG` have prospective merge/stop criteria. A technically useful capability is not sufficient reason for a standalone paper.

## 19. Current programme state

At the 2026-09-18 research-manifest update:

- five publication hypotheses are defined, with `PUB-RC` and `PUB-SG` explicitly conditional;
- `PUB-ME`, `PUB-SQ` and `PUB-GC` have prospectively defined confirmatory decision structures;
- five paper-level research manifests now specify primary endpoints, design versus holdout roles, threshold-freeze rules, exclusions and kill/merge criteria;
- `PUB-GC` already has a bounded scientific contract and experiment ladder with active research branches;
- existing SWAP5 governance provides substantial source/evidence traceability;
- the doctoral framing remains prospective and has not yet been evaluated against a specific university's formal PhD requirements.

The immediate purpose is therefore not to claim that a PhD already exists, but to ensure that current research decisions preserve the option of forming a coherent, evidence-rich doctoral thesis.

## 20. Governing principle

> Do not build several papers and later search for a thesis. Build a coherent research argument whose independently publishable studies can later be synthesized into a thesis.
