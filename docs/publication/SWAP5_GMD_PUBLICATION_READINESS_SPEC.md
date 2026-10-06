# SWAP5 → GMD publication readiness specification

Status: planning / evidence-preservation policy
Target: a future broad SWAP5 reference/model-description paper in *Geoscientific Model Development* (GMD)
Decision date: 2026-10-06

## Purpose

Preserve, during the remaining SWAP5 development and qualification work, the evidence needed to construct a rigorous and reproducible model-description paper without later reconstructing provenance from Git history.

This document does **not** preregister scientific novelty, freeze SWAP5, or commit the project to submission to GMD. GMD is the current preferred venue for the broad SWAP5 reference paper; Environmental Modelling & Software remains a candidate for narrower methodological work.

## Publication boundary

The broad paper should answer:

1. What is SWAP5?
2. Which process capabilities does the release contain?
3. How is the model organised for standalone, multi-column and coupled simulation?
4. Which numerical and state-management contracts are part of the model?
5. How was migration from the mature SWAP4 lineage verified?
6. What independent benchmarks and application tests demonstrate intended behaviour?
7. What are the documented limits of the released version?
8. How can another researcher obtain the exact code, inputs, scripts and evidence needed to reproduce the paper?

The paper must not consume novelty reserved for dedicated research lines such as DIFFICULTY, NUM-UNC, TRACE, HYDRO-MEMORY, COUPLE or other future papers. It may describe capabilities and evidence needed to document SWAP5, but should avoid claiming general scientific conclusions belonging to those workstreams.

## Release requirement

Submission should follow a real release boundary:

SWAP4.3.1 functional-coverage closure
→ integration and regression qualification
→ feature freeze
→ release candidate
→ paper experiment suite
→ SWAP 5.0.0 (or explicitly chosen paper release)
→ persistent source archive with DOI
→ persistent paper reproduction archive with DOI
→ manuscript submission

The manuscript must identify the exact model version in the title and text. The archived source must correspond exactly to the version used for the published experiments.

## Evidence to preserve from now on

For every substantial admitted capability, preserve where feasible:

- canonical commit SHA and admission/closeout identity;
- source authority and implementation scope;
- qualification commands or workflow definition;
- machine-readable result/status;
- exact test inputs;
- compiler/platform information where numerically relevant;
- O0/O2 or equivalent numerical-build evidence where relevant;
- mass-balance evidence;
- restart/continuation evidence;
- reject/replay evidence where transactional semantics matter;
- known exclusions and negative results;
- links between result artifacts and the exact tested source;
- enough information to rerun the test without relying on ephemeral CI artifacts.

Do not widen tolerances or discard negative results for publication convenience.

## Paper experiment classes

The final paper suite should be smaller than the complete migration test suite. It should contain deliberately selected, independently interpretable experiments.

### P1 — constitutive and process verification
Representative tests of core soil-water-atmosphere-plant processes. Select tests that demonstrate the released model, not every historical migration unit.

### P2 — numerical conservation and reproducibility
Water/mass conservation, accepted-state semantics, deterministic/reproducible behaviour where expected, restart continuation and relevant build/compiler checks.

### P3 — legacy-lineage reconciliation
A bounded set demonstrating that scientifically relevant SWAP4 behaviour was either preserved, intentionally changed with evidence, or explicitly excluded. Avoid presenting source-code identity as scientific validation.

### P4 — multi-column / application-scale execution
Demonstrate that the same scientific model can be executed as many independent columns with preserved state isolation and reproducible aggregation. Include realistic scale and performance characterization without turning the reference paper into the ACCELERATE paper.

### P5 — SWAP–MODFLOW6 coupling benchmark
Prefer an independently interpretable benchmark such as F-GC-STRIP01: analytical MODFLOW reference → transient drain-down → coupled simple forcing → dynamic forcing. Show conservation and physically meaningful spatial response. Do not require equality of MODFLOW head and SWAP freatic groundwater level where the coupling concept does not imply it.

### P6 — representative application
At least one application-scale case that demonstrates practical use across heterogeneous soils/forcing. Select only after the model release boundary is stable.

### P7 — optional solver/approximation capability
If alternative numerical routes (e.g. SSS or qualified approximate modes) are part of the release, document their status and bounded applicability. Do not claim equivalence beyond evidence.

## Figure/data provenance rule

Every quantitative manuscript figure and table should be regenerable by a repository script from an immutable experiment result.

Preferred chain:

release SHA/tag
→ experiment manifest
→ raw/model output
→ analysis script
→ machine-readable derived data
→ figure/table
→ manuscript claim

For each final figure/table preserve:
- generating script;
- source result identifiers;
- model release SHA/tag;
- input/configuration hashes or manifest;
- plotting/analysis environment where needed;
- a concise statement of what claim the item supports.

No important scientific figure should depend only on a manually edited spreadsheet or an untracked local file.

## Reproduction package

Prepare a publication-specific archive separate from the development repository when the paper freezes. It should contain, or point persistently to:

- exact SWAP release source archive;
- licence and citation information;
- build instructions;
- supported/tested compiler information;
- minimal smoke example;
- paper experiment manifests;
- inputs that can legally be redistributed;
- scripts required to rerun or regenerate paper analyses;
- derived data behind figures and tables;
- figure-generation scripts;
- machine-readable provenance manifest;
- README with expected runtime/storage requirements;
- checksums;
- known platform or dependency limitations.

Large or restricted datasets should have persistent references and a documented acquisition/preparation path. Never claim reproducibility for inputs that a reader cannot obtain.

## Candidate manuscript architecture

Working title pattern:

“SWAP 5.0: [concise description of the model and its intended coupled/scalable use]”

Provisional sections:

1. Introduction and model lineage
2. Scientific scope and governing process representation
3. Software and state architecture
4. Numerical solution and temporal/state contracts
5. Multi-column and coupling architecture
6. Verification and qualification strategy
7. Benchmark experiments
8. Application-scale demonstration
9. Computational characteristics
10. Limitations and intended use
11. Code and data availability
12. Conclusions

This is a planning scaffold, not a fixed outline.

## Claim firewall

Before admitting a manuscript claim, classify it:

A. model-description claim — belongs in GMD;
B. bounded verification/evaluation claim — may belong in GMD;
C. general methodological/scientific novelty — check against dedicated publication workstreams;
D. unsupported or not independently reproducible — exclude until evidence exists.

Examples of material to firewall unless separately agreed:
- prospective physical prediction of numerical difficulty;
- numerical uncertainty changing scientific inference;
- general theory-documentation-code-evidence discrepancy claims;
- hydrological-memory novelty;
- general coupling theory beyond what is needed to document the released interface;
- general error-bounded acceleration theory.

## Readiness gates

### G0 — evidence-preservation active
This document exists and new work can preserve publication-useful provenance.

### G1 — functional scope frozen
The intended paper release has a defined capability matrix and explicit exclusions.

### G2 — release candidate qualified
Regression, conservation, restart and application gates required for the release pass.

### G3 — paper suite frozen
P1–P7 selections are documented with independent rationale and no hidden cherry-picking.

### G4 — exact release archived
Source release is tagged and persistently archived with DOI.

### G5 — reproduction package archived
Inputs, scripts and derived data required for the paper are persistently archived with DOI(s), subject to legitimate data restrictions.

### G6 — manuscript traceability complete
Every central quantitative claim maps to a figure/table/experiment and exact archived evidence.

### G7 — submission ready
Journal format, code/data availability, author contributions, conflicts/funding, references, supplementary material and reproduction instructions are complete and independently checked.

## Repository organisation

Do not reorganise active migration evidence merely for the paper. At feature freeze create a publication view that references canonical evidence.

Suggested future structure:

publication/swap5-gmd/
  README.md
  manuscript/
  experiments/
  analysis/
  figures/
  tables/
  reproduction/
  archive_manifest/
  claim_evidence_matrix/

Until then, keep this readiness specification under documentation/publication governance and add publication-specific files only when they serve current work.

## Immediate policy

From 2026-10-06 onward:

1. preserve exact source identity for important qualification results;
2. prefer machine-readable results alongside prose closeouts;
3. keep negative findings and scope exclusions;
4. preserve independent oracles when they exist;
5. make new benchmark analyses script-reproducible;
6. do not let publication needs distort migration/admission decisions;
7. flag unusually strong evidence that may later serve P1–P7;
8. defer final experiment selection until functional coverage and release scope are stable.

## Decision note

Current strategy:
- GMD: preferred venue for the broad canonical SWAP5 model-description/reference paper;
- Environmental Modelling & Software: retain for a sharper generalisable methodological/software-science contribution if supported by dedicated evidence;
- do not duplicate the scientific novelty claims of dedicated PhD publication lines in the broad SWAP5 paper.
