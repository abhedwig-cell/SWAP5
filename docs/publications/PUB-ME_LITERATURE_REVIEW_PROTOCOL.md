# PUB-ME literature review protocol

Status: **prospective scoping-review protocol for novelty adjudication**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Protocol date: 2026-09-18

## 1. Review objective

The review is designed to answer a falsification question:

> Does prior work already provide and empirically demonstrate a method equivalent in substance to the proposed PUB-ME combination of scientific-state authority, staged semantic modernization, and change-aware scientific qualification evidence?

The objective is not to maximize the number of supportive references. Close negative prior art has priority because it directly determines whether `PUB-ME` remains a defensible standalone publication.

## 2. Current candidate contribution under test

The candidate contribution is provisionally defined as the combination of:

1. accepted scientific state distinguished from speculative candidate state and disposable numerical workspace;
2. fail-closed rejection/retry/rollback so non-authoritative work cannot become accepted scientific history;
3. preservation judged over scientific trajectories, balances, restart/state-transition semantics and declared numerical envelopes;
4. staged architectural migration in bounded semantic capabilities with explicit claims and nonclaims;
5. qualification evidence whose validity is linked to scientific/semantic dependencies and is explicitly reused, replayed, invalidated or superseded as the implementation evolves;
6. longitudinal demonstration that later solver substitution and model coupling can attach to the preserved authority boundary without silently changing the reference scientific denominator.

No individual item above is assumed to be novel. The review tests whether their combination, purpose and empirical demonstration are already established.

## 3. Review type

Use a **systematic scoping review with adversarial novelty adjudication**, rather than claiming a full systematic review unless database coverage and screening records later satisfy that standard.

Reasons:

- relevant prior art spans hydrology, Earth-system modelling, scientific software engineering, simulation, numerical analysis, co-simulation, software evolution and assurance engineering;
- terminology differs strongly across communities;
- exact phrase matching is unlikely to recover all conceptually equivalent work;
- backward and forward citation chasing are therefore mandatory.

## 4. Evidence classes

Classify each source before using it for novelty conclusions.

### A. Peer-reviewed close prior art

Journal or conference paper directly relevant to scientific-model modernization, behavior preservation, scientific-state semantics or evidence evolution.

Highest weight for novelty adjudication.

### B. Peer-reviewed adjacent prior art

Relevant concepts demonstrated in another software/simulation domain, for example transactional simulation, change-impact analysis or assurance cases.

Can invalidate broad novelty claims even if the domain differs.

### C. Standards / mature technical infrastructure

Examples: BMI, OpenMI, FMI, PETSc.

Used to establish that an execution/interface/numerical capability is already standard or mature. Do not treat documentation alone as proof of a research contribution.

### D. Preprints / emerging work

Relevant recent work not yet peer reviewed.

Track because it affects priority risk and future reviewer expectations, but mark the review status explicitly.

### E. Non-scholarly leads

Blogs, project pages and secondary summaries may identify terminology or papers but cannot by themselves support manuscript novelty claims.

## 5. Search clusters

Search each cluster independently, then cross-link references.

### C1. Hydrologic and Earth-system model modernization

Concepts:
- legacy hydrologic model modernization;
- land-surface model refactoring;
- climate/Earth-system model reprogramming;
- physics-preserving refactor;
- modular scientific model architecture;
- process-based model interoperability.

Known anchors: Noah-MP v5, WaterGAP reprogramming, SUMMA.

### C2. Scientific software behavior preservation and equivalence

Concepts:
- behavior-preserving refactoring;
- legacy reimplementation equivalence;
- numerical equivalence testing;
- differential testing scientific software;
- semantic regression;
- reference implementation / regression oracle;
- compiler/precision sensitivity.

### C3. Scientific software testing and continuous verification

Concepts:
- continuous verification numerical simulation;
- regression testing scientific software;
- metamorphic testing;
- property/invariant testing;
- adversarial/fault-injection validation;
- scientific software oracle problem.

### C4. State authority, speculative execution and rollback

Concepts:
- transactional simulation;
- speculative simulation state;
- candidate/current/committed state;
- rollback/retry/checkpoint scientific simulation;
- optimistic discrete-event simulation;
- rejected adaptive timesteps;
- state save/restore.

### C5. Co-simulation and model-state contracts

Concepts:
- FMI rollback;
- iterative co-simulation;
- communication-step rejection;
- model state serialization;
- conservative coupling;
- same-origin replay;
- waveform relaxation.

### C6. Software change impact and selective requalification

Concepts:
- change impact analysis;
- regression test selection;
- dependency-aware testing;
- incremental verification;
- proof/evidence reuse;
- semantic dependency analysis.

### C7. Evolving assurance and evidence validity

Concepts:
- assurance case evolution;
- evidence invalidation after change;
- safety case maintenance;
- continuous assurance;
- claim-evidence traceability;
- change-aware certification.

### C8. Reproducibility, provenance and scientific workflow evolution

Concepts:
- research software provenance;
- computational reproducibility;
- FAIR4RS;
- executable research objects;
- workflow evolution/version provenance;
- claim-to-code traceability.

## 6. Search strategy

For each cluster:

1. search recent work first to identify current terminology;
2. identify review papers and canonical frameworks;
3. search backward from close comparator papers;
4. search forward citations for later refinements;
5. search exact concepts plus domain synonyms;
6. search title/abstract combinations rather than relying on one keyword;
7. repeat with `hydrologic`, `environmental`, `Earth system`, `scientific software`, `simulation`, and `numerical model` variants;
8. record duplicate or irrelevant terminology so the search can be reproduced.

Target coverage should include, where accessible:

- Web of Science / Scopus-level bibliographic indexing or equivalent scholarly search;
- publisher databases and journal sites;
- Crossref/DOI metadata;
- Google Scholar-style citation chasing where available;
- IEEE/ACM/Springer/Elsevier/Copernicus/JOSS literature;
- arXiv only as a separate emerging-work layer.

Database incompleteness must be reported rather than hidden.

## 7. Time window

Primary structured search: 2000 through 2026.

Earlier foundational work is included when recovered through reviews/citation chasing, especially for simulation transactions, rollback, verification/validation and legacy software evolution.

The literature cut-off date must be recorded in the manuscript because this area is currently moving quickly.

## 8. Inclusion criteria

Include a work when at least one of the following applies:

- it modernizes/refactors/reimplements a mature scientific or simulation model;
- it evaluates preservation/equivalence across old and new implementations;
- it formalizes accepted/provisional state, rollback, retry or commit in simulation;
- it links software changes to verification/evidence impact;
- it provides a method for maintaining qualification/assurance evidence during evolution;
- it is a mature standard/infrastructure that makes a claimed capability non-novel;
- it explicitly discusses scientific-model reproducibility/provenance under software evolution.

## 9. Exclusion criteria

Exclude from the primary novelty matrix when the work:

- merely uses a scientific model without evolving its implementation;
- discusses generic refactoring with no behavior/evidence relevance and adds nothing beyond existing reviews;
- addresses model calibration/validation against observations without software-evolution relevance;
- is a non-scholarly summary whose primary source can be obtained;
- uses the same terminology but a substantively unrelated concept.

Excluded works may remain in the search log with a reason.

## 10. Extraction fields per source

For every retained source record:

```yaml
reference:
  authors: []
  year:
  title:
  venue:
  doi_or_stable_id:
  evidence_class: A | B | C | D | E
  peer_reviewed: true | false | unknown

research_object:
  domain:
  legacy_or_greenfield:
  model_or_software_type:

establishes:
  - <specific demonstrated result>

does_not_establish_from_reviewed_material:
  - <explicitly bounded absence, not an assertion that the authors never considered it>

novelty_impact:
  removes_claims: []
  weakens_claims: []
  leaves_open: []

empirical_strength:
  case_count_or_scope:
  comparator:
  metrics:
  longitudinal: true | false | unclear

manuscript_use:
  introduction:
  methods_boundary:
  discussion:

review_notes:
  exact_sections_or_pages:
  uncertainties:
```

The phrase `does not establish from reviewed material` is deliberate. Absence must not be overstated as proof that a source never addresses a concept.

## 11. Novelty adjudication rules

A proposed PUB-ME claim is **removed** when prior peer-reviewed work already demonstrates substantially the same contribution for a comparable scientific/simulation problem.

A claim is **weakened** when the individual mechanism is established elsewhere but the scientific-model-evolution combination or empirical evidence differs.

A claim remains **open** only when:

- no close equivalent has been found after cluster search and citation chasing;
- the distinction can be expressed operationally;
- SWAP5 can test it empirically;
- the claim does not depend on terminology alone.

`No source found` is not equivalent to `novel`. Manuscript wording should use bounded formulations such as `we are not aware of prior work that combines ...` only after review closure.

## 12. Red-team questions for every candidate novelty

For each proposed claim ask:

1. Is this simply known software engineering applied to hydrology?
2. Is this already done in a different simulation community under different terminology?
3. Is the only novelty the name we give it?
4. Could a reviewer point to Noah-MP, SUMMA or WaterGAP and say the paper adds no scientific method?
5. Could change-impact/assurance literature reproduce the evidence logic without hydrologic knowledge?
6. What observable failure does our method prevent or expose that ordinary regression testing would miss?
7. Can that difference be demonstrated prospectively rather than reconstructed from development history?
8. What negative result would make us abandon or narrow the claim?

## 13. Initial high-risk new lead: differential fault injection

Coleman, Shen, Sosonkina and Xu (2026), *Validating LLM-Modernized Scientific Software Through Differential Fault Injection*, arXiv:2608.14527.

Status: **preprint / emerging work**, not treated as peer-reviewed authority at this stage.

Why it matters:
- explicitly targets legacy Fortran scientific-software modernization;
- argues nominal regression/equivalence is insufficient;
- uses paired deterministic fault injection to compare legacy and modernized scientific kernels under off-nominal conditions;
- demonstrates that modernization validation can be framed as a scientific experiment rather than ordinary clean-run regression.

Novelty impact:
- further weakens any broad PUB-ME claim around adversarial testing, differential validation or testing beyond nominal executions;
- does not, from the reviewed abstract/material, establish the full accepted-state authority plus longitudinal evidence-evolution method targeted by PUB-ME.

Action:
- retain as an emerging priority-risk source;
- check for later peer-reviewed publication before manuscript submission;
- use it to strengthen, not weaken, the design of PUB-ME adversarial experiments.

## 14. Review stopping rule

Do not close novelty review merely because a plausible story has emerged.

A cluster can be considered provisionally saturated only when:

- repeated synonym searches return mostly already screened concepts;
- at least one recent review or canonical work has been backward/forward chased;
- close comparators have been read beyond abstracts where accessible;
- newly found sources cease to remove or materially narrow the candidate claim.

The review remains living until manuscript submission.