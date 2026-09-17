# Five-paper research-manifest index

Status: **draft freeze candidates**

Branch: research/phd-five-paper-manifests-20260918

Parent research state: `4384a047e10f78f2b30a713577119a4fd75cbb97`

These manifests translate the existing scientific contracts into prospective decision rules for
confirmatory research. They do not replace the scientific contracts or existing experiment manifests.

## Portfolio

| Paper | Role | Manifest status | Primary confirmatory decision |
| --- | --- | --- | --- |
| PUB-ME | PRESERVE | draft freeze candidate | Does explicit scientific-state authority prevent or localize prospectively defined contamination faults beyond a matched conventional architecture? |
| PUB-SQ | REPLACE | draft freeze candidate | Does candidate-independent admission transfer to untouched regimes, and what is the common admissible cost-error domain? |
| PUB-GC | COUPLE | draft freeze candidate | Does the finite-window contract conserve, converge and transfer from transparent GW-A to MODFLOW 6 without dependence on internal step partition? |
| PUB-RC | ACCELERATE | conditional | Does hydrologic response information beat strong generic black-box acceleration at matched coupled error after response cost is counted? |
| PUB-SG | SCALE | conditional | Does a frozen equivalent column lose cross-regime transferability in a reproducible, mechanistically interpretable part of the domain? |

## Dependency graph

PRESERVE is foundational but does not own later numerical results.

REPLACE and COUPLE are scientifically parallel once the relevant state/transaction authority exists.

ACCELERATE depends on a stable COUPLE method and may be merged into PUB-GC if hydrologic response
information provides no distinct benefit.

SCALE depends on conservative N-to-1 COUPLE semantics but does not depend on ACCELERATE.

## Freeze policy

A manifest may move from DRAFT_FREEZE_CANDIDATE to FROZEN only when:

1. the stated comparator is available and scientifically fair;
2. numerical-reference construction is executable;
3. primary endpoints can be extracted without changing production semantics;
4. any materiality thresholds are frozen from independent authority or pre-result calibration;
5. holdout cases are identified by immutable case/forcing/input fingerprints;
6. the code authority and compiler/runtime authority are recorded;
7. exclusion and stop/merge rules are accepted before confirmatory outcomes are inspected.

Do not create numerical thresholds merely for completeness. Where no defensible independent
threshold exists yet, freeze the threshold-construction procedure first and delay confirmatory runs.

## Cross-paper anti-duplication rules

PUB-ME owns causal state-authority/fault-containment evidence, not solver or coupling performance.

PUB-SQ owns solver admission and matched-error solver cost, not groundwater-coupling accuracy.

PUB-GC owns conservation, same-origin/whole-window semantics and coupling convergence, but not
response-acceleration novelty or the hydrologic value of subgrid heterogeneity.

PUB-RC owns the incremental value of interface response information over strong black-box baselines.

PUB-SG owns cross-regime representativeness of explicit versus equivalent vadose columns.

A raw run may support more than one paper only if figure/table ownership and the non-overlapping
claim are recorded in the experiment manifest.
