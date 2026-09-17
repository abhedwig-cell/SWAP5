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

## 4. Research arc

The intended logical progression is:

```text
PRESERVE -> REPLACE -> COUPLE -> ACCELERATE -> SCALE
```

The steps mean:

- **PRESERVE**: modernize a legacy scientific model while demonstrating preservation of relevant scientific behaviour;
- **REPLACE**: make numerical components substitutable under explicit qualification rules;
- **COUPLE**: treat the model as a repeatable dynamic subsystem in conservative coupling with another process model;
- **ACCELERATE**: exploit subsystem response information to solve the coupled nonlinear problem more efficiently;
- **SCALE**: investigate when explicit subgrid heterogeneity materially changes regional coupled behaviour.

The final `SCALE` step is conditional and is not required for the minimum viable doctoral argument if the first four studies provide sufficient scientific depth and coherence.

## 5. Research questions and publication mapping

| Research question | Publication owner | Role in thesis |
| --- | --- | --- |
| RQ1. How can a mature process-based scientific model be structurally transformed while preserving defined scientific behaviour and qualification evidence? | `PUB-ME` | establishes the trustworthy evolution framework |
| RQ2. How can an alternative numerical solver be admitted without confusing numerical performance with scientific validity? | `PUB-SQ` | tests whether numerical substitution can be independently qualified |
| RQ3. How can independently time-integrating vadose-zone and groundwater models be coupled conservatively and reproducibly over finite coupling windows? | `PUB-GC` | tests composability and accepted-state coupling semantics |
| RQ4. Can whole-window response information from the vadose-zone subsystem accelerate the nonlinear coupled solve without weakening conservation or reproducibility? | `PUB-RC` | develops the coupling into a numerical-method contribution |
| RQ5. Under what conditions must heterogeneous vadose-zone responses be retained explicitly within coarser groundwater cells? | `PUB-SG`, conditional | tests hydrologic consequences of composability at scale |

## 6. Minimum viable thesis

The research programme must not depend on all five papers succeeding.

A coherent minimum doctoral core is provisionally:

1. `PUB-ME`;
2. `PUB-SQ`;
3. `PUB-GC`;
4. `PUB-RC` or another sufficiently independent fourth study that emerges from the programme.

`PUB-SG` is an optional fifth study and should only be promoted to a paper when the hydrologic results establish a distinct scientific question.

If `PUB-RC` fails scientifically because response information provides little benefit, that negative result should not be hidden. The doctoral architecture must allow the fourth study to be reframed around the validated numerical finding rather than preserving a predetermined paper count.

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

### Risk: fifth paper is forced

Mitigation: `PUB-SG` remains explicitly conditional.

## 19. Current programme state

At creation of this document:

- the publication portfolio contains four core publication lines and one conditional line;
- `PUB-GC` has a bounded scientific contract and experiment ladder;
- existing SWAP5 governance already provides substantial source/evidence traceability;
- the doctoral framing is prospective and has not yet been evaluated against a specific university's formal PhD requirements.

The immediate purpose is therefore not to claim that a PhD already exists, but to ensure that current research decisions preserve the option of forming a coherent, evidence-rich doctoral thesis.

## 20. Governing principle

> Do not build several papers and later search for a thesis. Build a coherent research argument whose independently publishable studies can later be synthesized into a thesis.
