# PUB-GC journal positioning and submission route

## Status

**PRIMARY TARGET: GEOSCIENTIFIC MODEL DEVELOPMENT (GMD)**  
**MANUSCRIPT TYPE: DEVELOPMENT AND TECHNICAL PAPER**

Decision date: 2026-09-18.

This positioning follows closure of E7 as `REALISTIC_COMPONENT_DOMAIN_LIMIT`. It changes no scientific claim, experiment, production code or qualification threshold.

## 1. Recommendation

### Primary target — Geoscientific Model Development

GMD is the strongest fit for the current manuscript because the paper's central contribution is a rigorously tested **model-development and coupling contract**:

- independent numerical ownership of SWAP5 and MODFLOW6;
- explicit hydrological interface semantics;
- replayable finite-window trials from immutable accepted state;
- exactly-once interface-mass authority;
- typed finite-window response information;
- explicit component/application admission domains;
- reproducible negative evidence when realistic process composition lies outside the admitted coupled participant.

GMD explicitly accepts development and technical papers, model experiments, model-assessment methods and full model evaluations. Its scope therefore matches the manuscript without requiring the paper to pretend that E7 produced a regional hydrological validation or a large realistic loose-versus-strong correction.

Official scope and policy checked 2026-09-18:

- https://www.geoscientific-model-development.net/about/aims_and_scope.html
- https://www.geoscientific-model-development.net/about/manuscript_types.html
- https://www.geoscientific-model-development.net/policies/code_and_data_policy.html
- https://www.geoscientific-model-development.net/submission.html

Recent GMD precedents show that the journal is actively publishing closely related model-development work:

- Müller et al. (2025), FINAM coupling framework, GMD 18, 4483–4511, https://doi.org/10.5194/gmd-18-4483-2025;
- Coxon et al. / DECIPHeR-GW development (2025), GMD 18, 4247–4274, https://doi.org/10.5194/gmd-18-4247-2025;
- He et al. (2025), H08-GMv1.0 coupling to MODFLOW, GMD 18, 9653–9690, https://doi.org/10.5194/gmd-18-9653-2025;
- Nyenah et al. (2025), reprogramming legacy WaterGAP as sustainable research software, GMD 18, 5635–5667, https://doi.org/10.5194/gmd-18-5635-2025.

These papers are precedents for venue fit, not novelty claims for PUB-GC.

### Strong secondary target — Environmental Modelling & Software

Environmental Modelling & Software is also a strong scope match. It explicitly publishes generic model-integration methods, software development, model evaluation, quality assurance and surface/subsurface hydrological modelling.

Official scope checked 2026-09-18:

- https://shop.elsevier.com/journals/environmental-modelling-and-software/1364-8152

A particularly close current precedent is Trim et al. (2025), *Enhancing the modularity and interoperability of hydrologic models: A demonstration with SUMMA*, Environmental Modelling & Software 194, 106668, https://doi.org/10.1016/j.envsoft.2025.106668.

That precedent confirms excellent audience fit but also raises the novelty burden around generic modularity/interoperability. PUB-GC would therefore need to foreground its narrower evidence-based contribution: state/mass authority, finite-window map identity and explicit component-domain classification rather than generic modularity.

### Reserve target — Hydrology and Earth System Sciences

HESS explicitly welcomes work advancing hydrological modelling and soil-water/interfacial-flux understanding.

Official scope checked 2026-09-18:

- https://www.hydrology-and-earth-system-sciences.net/about/aims_and_scope.html

HESS is credible, but the present paper is more naturally a model-development/method paper than a paper whose primary result is new hydrological process understanding. HESS becomes more attractive only if the manuscript is later re-centred around a stronger hydrological inference.

### Not first-choice targets in the current evidence state

**Water Resources Research** and **Advances in Water Resources** both accept numerical hydrology, but their current scope emphasizes broader or more fundamental advances in water science. The present manuscript deliberately does not claim a realistic coupled Hupsel correction magnitude, regional groundwater validation or a new fundamental flow law. Submitting there first would create avoidable pressure to overstate E3–E7.

## 2. GMD manuscript-type binding

Use:

> **Development and technical paper**

Do not submit as a pure model-evaluation paper. The manuscript describes and evaluates a new coupling development and its scientific/numerical contract.

The title must identify the relevant model version or unique identifier. GMD explicitly requires this for model-development papers and for model-specific demonstrations of a general advance.

Current working title:

> Hydrologically accountable finite-window coupling of independently time-integrating vadose-zone and groundwater models: SWAP5–MODFLOW6

Submission title should be finalized only after the exact SWAP5 release is frozen. A GMD-compatible pattern is:

> **Hydrologically accountable finite-window coupling of SWAP5 (version X) and MODFLOW 6.8.0**

Do not invent the SWAP5 version number before the archival release exists.

## 3. Submission-critical GMD requirements

### G1 — Freeze an exact SWAP5 archive

**REQUIRED BEFORE SUBMISSION.**

GMD requires a persistent public archive with a unique identifier for the precise source-code version used in the paper. A live GitHub branch alone is not sufficient.

Required action:

1. freeze the exact canonical SWAP5 submission revision;
2. create a permanent archive/release with DOI or equivalent persistent identifier;
3. cite that archive in the manuscript and reference list;
4. retain the GitHub repository as the development location in addition to the archive.

This is now the main external submission prerequisite.

### G2 — Freeze the complete reproduction package

GMD expects preprocessing, run-control and postprocessing scripts covering the reported results.

The repository already contains the publication evidence, figure-generation scripts and workflow provenance. Before submission, the frozen archive must include or point persistently to:

- exact E1–E7 result JSON/CSV;
- publication figure scripts and SVG sources;
- exact configuration/test inputs that are legally redistributable;
- scripts/workflows needed to reproduce the reported controlled cases;
- documented compiler/runtime dependencies;
- MODFLOW 6.8.0 provenance.

### G3 — Handle the historical SWAP 4.3.1 asset explicitly

The historical SWAP 4.3.1 distribution is not redistributed in this repository.

The GMD code/data statement must:

- give its exact SHA-256 and size;
- explain why the asset is not publicly redistributed;
- distinguish the external historical reference asset from the public SWAP5 code developed in this paper;
- provide reviewer/editor access where legally and practically possible;
- never imply that the external legacy distribution is part of the public SWAP5 archive.

The publication evidence itself is already designed not to require redistribution of that archive for inspection of the reported E1–E7 conclusions.

### G4 — Add GMD end matter

Before submission add/finalize:

- **Code and data availability** with persistent archive citations;
- **Author contribution**, preferably using CRediT roles;
- acknowledgements;
- funding information;
- competing interests declaration;
- any required AI-tool-use disclosure;
- exact author names, affiliations and corresponding-author details.

### G5 — Convert to Copernicus submission format

Prepare the manuscript in the current GMD/Copernicus template with:

- numbered sections;
- line and page numbers for review;
- individual submission-quality figure files;
- full reference normalization;
- model/version identifiers in the title;
- figure and table captions in GMD format.

### G6 — Prepare the required short summary

GMD requests a non-technical summary of at most 500 characters including spaces.

Working candidate:

> Vadose-zone and groundwater models often exchange water while keeping separate numerical solvers. We developed a coupling contract for SWAP5 and MODFLOW6 that separates trial calculations from accepted state and water balance. Controlled tests show reliable but weak feedback, while a realistic Hupsel case reaches a process-domain boundary before coupling, showing that component admissibility is part of the coupled-model problem.

Recheck the exact character count before submission.

### G7 — Select a key figure

Preferred current candidate: **Figure F1**, because it communicates the general coupling contribution rather than only the E7 negative boundary.

F7 remains important in Results but should not become the graphical abstract if that makes the paper appear to be primarily a failed Hupsel application.

## 4. Claim positioning for GMD

The journal-facing central statement should remain:

> The contribution is a solver-autonomous, hydrologically accountable finite-window coupling contract in which physical exchange meaning, model-state authority, interface-mass authority and component-admission domains remain simultaneously testable.

Do not promote any of the following into novelty claims:

- solver autonomy itself;
- checkpoint/restore;
- partitioned or iterative coupling;
- Aitken/IQN/secant acceleration;
- derivative or Jacobian exposure;
- MODFLOW external API control;
- generic model modularity;
- N:1 mapping as software capability.

The strongest manuscript-specific evidence remains the combination of:

1. typed hydrological exchange quantities;
2. immutable accepted origins for repeated finite-window trials;
3. exactly-once accepted interface mass;
4. explicit distinction between flux-driven and head-driven finite-window response maps;
5. measured limited incremental value of exact derivative information in the controlled problem;
6. explicit separation of component-domain failure from outer-coupling failure;
7. prospectively selected realistic E7 evidence showing that the application-owner domain can be reached before outer coupling begins.

## 5. GMD submission go/no-go

### Scientific gate

**GO.**

RQ1–RQ5 are closed within their bounded evidence states. No new primary experiment is required for the current manuscript.

### Repository/evidence gate

**GO.**

Canonical E7 closure and publication assets are admitted. Current manuscript/claim audits report no claim-ledger overrun.

### Archival gate

**NOT YET CLOSED.**

A persistent archive/DOI for the exact SWAP5 submission revision is still required.

### Editorial gate

**NOT YET CLOSED.**

Author metadata, final versioned title, GMD formatting, code/data availability wording and the 500-character summary must be finalized.

## 6. Submission sequence

1. preserve the current E1–E7 scientific denominator;
2. freeze the SWAP5 submission release;
3. archive code/evidence/scripts persistently and obtain DOI;
4. bind the final SWAP5 version identifier into title and Code/Data Availability;
5. convert manuscript and figures to GMD format;
6. run final claim, reference, notation and archive-identity audits;
7. prepare cover letter and submission metadata;
8. submit as a **Development and technical paper**.

If GMD is not pursued, Environmental Modelling & Software is the preferred second route. Re-targeting to EMS should change framing and formatting only, not manufacture additional scientific evidence.
