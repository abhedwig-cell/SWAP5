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
| `PUB-ME-E0` reference lineage | PUB-ME | supporting/foundational | READY_FOR_SCREENING | migration-slice candidate set frozen in `PUB-ME_MIGRATION_SLICES.md`; recover exact historical pre/post authorities for ME-S1/ME-S2/ME-S3 |
| `PUB-ME-E1` preservation reruns | PUB-ME | primary | DESIGNED | reconstruct exact historical build/input authorities for selected slices and freeze common benchmark set |
| `PUB-ME-E2` candidate-leak adversarial | PUB-ME | primary | DESIGNED | define qualification-only fault-injection harness; never production |
| `PUB-ME-E3` restart sufficiency | PUB-ME | primary | READY_FOR_SCREENING | select benchmark cases with/without prior retry and instantiate manifest |
| `PUB-ME-E4` semantic-successor evidence | PUB-ME | primary | READY_FOR_SCREENING | ME-S5 frozen as semantic-successor Case B; freeze exact unrelated-change Case A from ME-S6 before detailed extraction |
| `PUB-ME-E5` qualification-surface analysis | PUB-ME | supporting | DESIGNED | define repository-derived surface metrics; no person-hour claims |
| `PUB-ME-E6` extensibility cases | PUB-ME | supporting | READY_FOR_SCREENING | extract solver-seam and groundwater-seam dependency evidence |
| `PUB-SQ-E0` contract/fail-closed | PUB-SQ | prerequisite/supporting | COMPLETE | `PUB-SQ-E0-0001` completed under manifest control; continue with SQ-E1 common-domain/reference design, not additional post-hoc E0 cases |
| `PUB-SQ-E1` common-domain equivalence | PUB-SQ | primary | DESIGNED | freeze stratified case matrix and build `REF-HIGH` procedure |
| `PUB-SQ-E2` admissibility boundary | PUB-SQ | primary | DESIGNED | reconcile exact RossFast envelope and choose paired inside/boundary/outside cases |
| `PUB-SQ-E3` equal-error cost | PUB-SQ | primary | BLOCKED | accuracy thresholds + stable `REF-HIGH` required first |
| `PUB-SQ-E4` trajectory accumulation | PUB-SQ | primary | DESIGNED | choose common-domain forcing sequences after SQ-E1 screening |
| `PUB-SQ-E5` expanded scientific domain | PUB-SQ | future | BLOCKED | requires separate RossFast domain qualification |
| `PUB-GC-E0` interface conservation | PUB-GC | prerequisite/supporting | READY_FOR_SCREENING | `PUB-GC-E0-0001` was invalid before its scientific oracle; replacement `PUB-GC-E0-0002` is preregistered against the exact independent F-VQ87 postimage and may now execute |
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

1. `PUB-ME-E0`: recover exact authorities for the already frozen migration-slice candidate set;
2. `PUB-ME-E4`: freeze the exact unrelated-change Case A paired with frozen semantic-successor Case B;
3. `PUB-GC-E0`: execute only the preregistered replacement `PUB-GC-E0-0002` against its pinned F-VQ87 authority;
4. `PUB-GC-E6`: re-express bounded N:1 conservation cases under publication manifests;
5. `PUB-SQ-E0`: no further screening cases are added post hoc; the family is complete and hands off to SQ-E1 reference/common-domain design.

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

## Readiness chronology

### 2026-09-17T18:31Z — PUB-SQ-E0 screening completed

- controlling manifest commit: `892a7d13631dd226850a6c5f6869e1d7567bf909`;
- result receipt commit: `7cfe328e3fa46231837eb41cace5cab11fb05f84`;
- prerequisite satisfied: manifest-controlled contract/fail-closed screening executed;
- next permitted action: SQ-E1 reference/common-domain design;
- cross-publication effect: none; no GC, ME or RC primary claim is inherited.

### 2026-09-17T18:31Z — PUB-GC-E0 first execution invalidated

- controlling manifest commit: `9bdd605ad2d6189f431e513e955bbb53ce01f28a`;
- invalid-execution receipt commit: `aacbfceb2ca18145e693af952d177f3d4784fbaf`;
- prerequisite invalidated: the old owner runner was not a valid build harness for the later moving canonical source graph;
- next permitted action: new manifest required before changing execution route;
- cross-publication effect: none; no scientific GC result was admitted from the invalid attempts.

### 2026-09-17T18:33Z — PUB-GC-E0 replacement preregistered

- controlling manifest commit: `71b7904a3ddee39c7e3a92c5f1dc23d2feaeaafe`;
- prerequisite satisfied: exact independent F-VQ87 authority, runner blob and oracle-test blob frozen before execution;
- next permitted action: execute `PUB-GC-E0-0002` unchanged on the pinned F-VQ87 postimage;
- cross-publication effect: none; this remains PUB-GC supporting evidence and does not establish current-canonical generalized runtime qualification.

## Register update rule

Whenever a run family changes status, record:

- date/time;
- controlling commit;
- prerequisite newly satisfied or invalidated;
- next permitted action;
- whether the change affects another publication line.

The register should describe readiness, not rewrite past chronology.
