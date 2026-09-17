# Publication experiment register

Status: **living execution-readiness register**

Purpose: track which publication experiment families are ready for screening, reference construction or primary execution, and which prerequisites still block them.

This register does not contain scientific results. It is an execution map between the scientific contracts, experiment matrices and future run manifests.

## Status vocabulary

- `DESIGNED`: experiment family is specified but prerequisites are not all ready;
- `READY_FOR_SCREENING`: exploratory/supporting runs may begin;
- `READY_FOR_REFERENCE_CONSTRUCTION`: numerical-reference runs may begin;
- `READY_FOR_PRIMARY_FREEZE`: enough screening exists to freeze the primary matrix;
- `READY_FOR_PRIMARY_RUN`: primary matrix and all prerequisites are frozen;
- `BLOCKED`: a named scientific/technical prerequisite is missing;
- `COMPLETE`: run family completed under manifest control.

## Programme register

| Run family | Owner | Evidence role | Current status | Main blocker / next action |
| --- | --- | --- | --- | --- |
| `PUB-ME-E0` reference lineage | PUB-ME | supporting/foundational | READY_FOR_SCREENING | choose/freeze representative migration slices |
| `PUB-ME-E1` preservation reruns | PUB-ME | primary | DESIGNED | reconstruct exact historical build/input authorities for selected slices |
| `PUB-ME-E2` candidate-leak adversarial | PUB-ME | primary | DESIGNED | define qualification-only fault-injection harness; never production |
| `PUB-ME-E3` restart sufficiency | PUB-ME | primary | READY_FOR_SCREENING | select benchmark cases with/without prior retry |
| `PUB-ME-E4` semantic-successor evidence | PUB-ME | primary | READY_FOR_SCREENING | freeze longitudinal Case A and Case B before detailed extraction |
| `PUB-ME-E5` qualification-surface analysis | PUB-ME | supporting | DESIGNED | define repository-derived surface metrics; no person-hour claims |
| `PUB-ME-E6` extensibility cases | PUB-ME | supporting | READY_FOR_SCREENING | extract solver-seam and groundwater-seam dependency evidence |
| `PUB-SQ-E0` contract/fail-closed | PUB-SQ | prerequisite/supporting | READY_FOR_SCREENING | instantiate common manifest and select supported/unsupported Ross cases |
| `PUB-SQ-E1` common-domain equivalence | PUB-SQ | primary | DESIGNED | freeze stratified case matrix and build `REF-HIGH` procedure |
| `PUB-SQ-E2` admissibility boundary | PUB-SQ | primary | DESIGNED | reconcile exact RossFast envelope and choose paired inside/boundary/outside cases |
| `PUB-SQ-E3` equal-error cost | PUB-SQ | primary | BLOCKED | accuracy thresholds + stable `REF-HIGH` required first |
| `PUB-SQ-E4` trajectory accumulation | PUB-SQ | primary | DESIGNED | choose common-domain forcing sequences after SQ-E1 screening |
| `PUB-SQ-E5` expanded scientific domain | PUB-SQ | future | BLOCKED | requires separate RossFast domain qualification |
| `PUB-GC-E0` interface conservation | PUB-GC | prerequisite/primary table | READY_FOR_SCREENING | instantiate exact manifest from admitted GC v1 cases |
| `PUB-GC-E1` same-origin replay | PUB-GC | primary | DESIGNED | define diagnostic history-contaminated comparator and GW-A |
| `PUB-GC-E2` whole-window vs terminal flux | PUB-GC | primary | DESIGNED | define fair terminal-flux comparator and GW-A |
| `PUB-GC-E3` window convergence | PUB-GC | primary | BLOCKED | GW-A + converged replay method + `GC-REF` construction required |
| `PUB-GC-E4` robustness domain | PUB-GC | primary | BLOCKED | predeclared accuracy thresholds and GC-E3 reference required |
| `PUB-GC-E5` MODFLOW 6 transfer | PUB-GC | primary | BLOCKED | concrete scientifically admitted MODFLOW 6 backend |
| `PUB-GC-E6` bounded N:1 conservation | PUB-GC | supporting/primary table | READY_FOR_SCREENING | map existing F-GC25 cases into publication manifest without upscaling claims |
| `PUB-GC-E7` realistic demonstration | PUB-GC | supporting | BLOCKED | controlled GC-E1..E5 method evidence must exist first |
| `PUB-RC` response-assisted matrix | PUB-RC | future primary | BLOCKED | SWAP-side whole-window response / interface derivative method not yet established |
| `PUB-SG` heterogeneity matrix | PUB-SG | conditional future | BLOCKED | only start after PUB-GC coupling/reference basis is mature |

## Immediate executable tranche

The following work can begin without inventing new production science:

### Tranche A — evidence extraction and screening

1. `PUB-ME-E0`: freeze migration-slice candidates and exact authorities;
2. `PUB-ME-E4`: preselect one unchanged-dependency and one semantic-successor case;
3. `PUB-SQ-E0`: create manifest-backed supported/out-of-domain solver-selection cases;
4. `PUB-GC-E0`: re-express admitted interface conservation cases under publication manifests;
5. `PUB-GC-E6`: re-express bounded N:1 conservation cases under publication manifests.

These are primarily screening/foundational tasks. They should not be mistaken for final primary publication evidence.

### Tranche B — reference-construction preparation

In parallel, define:

- `PUB-SQ-REF-HIGH`: refinement procedure and stability criterion;
- `PUB-GC-GW-A`: transparent groundwater reservoir definition;
- `PUB-GC-GC-REF`: strict coupling reference procedure;
- shared publication telemetry serialization.

No primary claim run should begin until these definitions are frozen.

## Blocker policy

A `BLOCKED` experiment must fail closed. Do not substitute an easier method merely to obtain a green publication matrix.

Examples:

- no MODFLOW 6 claim without a scientifically conformed backend;
- no equal-error solver claim without a stable high-accuracy reference;
- no response-assisted claim without a qualified/defensible interface response;
- no subgrid-value claim without a credible effective comparator.

## Register update rule

Whenever a run family changes status, record:

- date/time;
- controlling commit;
- prerequisite newly satisfied or invalidated;
- next permitted action;
- whether the change affects another publication line.

The register should describe readiness, not rewrite past chronology.
