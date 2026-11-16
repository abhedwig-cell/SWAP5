# SWAP5 GMD manuscript skeleton

Status: living skeleton; not manuscript prose
Date: 2026-11-16
Target journal: Geoscientific Model Development
Target object: the first broad SWAP5 reference/model-description paper

## Scope decision 2026-11-16

The GMD paper is no longer blocked by complete macropore migration.

A scientifically and technically qualified SWAP5 core release may define the paper release even when preferential-flow/macropore functionality remains explicitly excluded. Any such exclusion must be visible in the title/version scope where needed, capability matrix, limitations section, archived release and code/data statement.

Macropore functionality may be admitted later in another SWAP5 version. The paper must not imply capability that is absent from the exact archived release.

## Working title candidates

Preferred pattern:
**SWAP 5.0: a process-based soil–water–atmosphere–plant model for reproducible, scalable and coupled hydrological simulation**

Alternative, if coupling is not part of the paper release:
**SWAP 5.0: redesign and qualification of a mature process-based soil–water–atmosphere–plant model**

Final title must match the exact release scope.

## Core paper proposition

SWAP5 is a new executable generation of the mature SWAP model lineage in which process physics, accepted state, continuation/restart, multi-column execution and external coupling are made explicit and reproducibly qualified. The paper describes the released model and its evidence; it does not claim that the migration method, coupling theory, numerical-difficulty behaviour or uncertainty results are generally novel.

## 1. Introduction and model lineage

### Intended claims
- SWAP has a long process-based soil–water–atmosphere–plant modelling lineage.
- Mature model evolution creates a need to preserve scientific capability while making execution, coupling and reproducibility tractable.
- SWAP5 is the next model generation, not merely a renamed executable.
- The paper's purpose is model description, qualification and bounded evaluation.

### Evidence needed
- canonical SWAP lineage references;
- SWAP 50 years reference;
- exact relationship between SWAP4.3.1 source authority and SWAP5 release;
- final release capability/exclusion matrix.

### Firewall
Do not turn the introduction into TRACE or make general claims about failures of legacy scientific software.

## 2. Scientific scope and process representation

Describe only capabilities present in the exact release.

Candidate process groups:
- variably saturated soil water flow;
- atmospheric boundary, ponding/runoff and evaporation;
- root water uptake and oxygen/water stress;
- crop/vegetation where admitted;
- drainage and lower boundaries;
- soil heat;
- solute and nutrient processes where admitted;
- snow/hysteresis and other original process families where admitted;
- irrigation/management where admitted.

Use a compact process table rather than narrating every migration workunit.

### Evidence
GMD-E1 plus final capability ledger.

### Macropore rule
If preferential flow/macropores are excluded from the paper release, state this once clearly here and describe it again under limitations. Do not describe experimental/non-admitted implementations as release capability.

## 3. Software, state and execution architecture

Describe:
- instance-owned state;
- accepted versus trial/proposed state where relevant;
- daily/subdaily execution;
- restart/continuation;
- external forcing interfaces;
- separation between scientific state and orchestration;
- standalone user route.

Use concrete SWAP5 architecture, not generic software-engineering claims.

### Evidence
Release architecture docs, standalone user qualification, restart evidence, Windows/Ubuntu release qualification.

## 4. Numerical solution

Describe released numerical routes only:
- Richards solution;
- nonlinear/linear solve strategy;
- timestep control;
- convergence/mass criteria;
- heat/other internal subcycling where relevant;
- constitutive alternatives actually admitted.

Report negative/excluded alternatives only when needed to define applicability.

### Firewall
No DIFFICULTY or NUM-UNC general claims. Performance changes that failed qualification remain negative evidence, not paper selling points.

## 5. Multi-column and coupled execution

### 5.1 MultiSWAP
Explain isolated column instances, aggregation/orchestration and scaling.

### 5.2 MODFLOW6 coupling
Include only if the interface is release-qualified. Explain physical ownership of exchanged state/flux/storage sufficiently to reproduce the model contract.

### 5.3 Other coupling interfaces
Ribasim or other interfaces only if they exist in the exact release. Future direction belongs in discussion, not capability claims.

### Evidence
GMD-E4 and GMD-E5.

### Firewall
General coupling theory belongs to COUPLE.

## 6. Verification and qualification approach

Explain the evidence hierarchy used for the release:
- source authority;
- independent/analytical oracles where available;
- regression where appropriate;
- conservation;
- restart/replay;
- platform/compiler checks;
- application trajectories;
- explicit exclusions and retained negative evidence.

### Evidence
GMD-E3 and release governance.

### Firewall
Do not present a general theory-documentation-code-evidence taxonomy; that belongs to TRACE.

## 7. Benchmark experiments

Provisional small suite:
- E1 representative process/constitutive benchmark;
- E2 integrated accepted-state/restart trajectory;
- E3 bounded lineage examples;
- E5 F-GC-STRIP01 if coupling is in release;
- E4 scaling as needed.

Each experiment must have a predeclared manuscript claim and exact archived evidence.

## 8. Application-scale demonstration

Choose one primary application only after release freeze.

Current candidates:
- Hupsel: attractive because complete public trajectory and hydrological familiarity;
- regional/MultiSWAP case: attractive for scale/coupling but potentially heavier data/reproduction burden;
- Andelst/Grassgrowth: useful as supporting qualification, not automatically the primary paper application.

Selection criteria:
- relevance to model scope;
- independent interpretability;
- legal/public data availability;
- reproducibility;
- manageable archive/runtime;
- no dependence on unpublished novelty claims.

## 9. Computational characteristics

Report:
- build/run environment;
- representative runtime/scaling;
- memory where relevant;
- reproducibility across supported platforms.

Separate model runtime from compilation, CI and test-harness cost.

Do not promise unsafe adaptive speedups or make broad acceleration claims.

## 10. Limitations and intended use

Must explicitly include:
- capabilities excluded from exact release;
- macropore/preferential-flow status if excluded;
- unqualified constitutive/numerical alternatives;
- coupling limitations;
- application domains not evaluated;
- known platform/numerical sensitivities that remain scientifically relevant.

A transparent limitations section is part of the model description, not a weakness to hide.

## 11. Code and data availability

Before submission require:
- exact tagged release;
- persistent source DOI;
- paper reproduction DOI/archive;
- build instructions;
- input and analysis scripts;
- figure/table regeneration;
- checksums/provenance;
- data acquisition route for any external dataset.

## 12. Conclusions

Keep narrow:
- what SWAP5 release contains;
- what evidence supports it;
- what execution/coupling scale it enables;
- what remains outside scope.

Do not conclude dedicated PhD-paper hypotheses.

## Planned figures/tables

Provisional:
1. SWAP lineage and SWAP5 architecture diagram.
2. Process/capability table with release status.
3. Accepted-state/execution architecture diagram.
4. E1 process benchmark.
5. E2 integrated trajectory/restart conservation.
6. Multi-column/scaling figure if retained.
7. F-GC-STRIP01 spatial coupling benchmark if release-qualified.
8. Primary application figure.
9. Table of limitations/exclusions and evaluation scope.

Final number should remain modest.

## Writing trigger

Do not begin full prose drafting until:
- release scope is stable enough to know which capabilities are in/out;
- exact macropore decision for the paper release is recorded;
- primary application is selected;
- at least E1/E2 and, if relevant, E5 can be regenerated from persistent evidence.

Until then update claims/evidence, not prose.
