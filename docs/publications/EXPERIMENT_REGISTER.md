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
| `PUB-ME-E2` candidate-leak adversarial | PUB-ME | primary | DESIGNED | paired B0/B1 causal design frozen in `PUB-ME-CONFIRMATORY-FREEZE-v1.yaml`; materialize research-only bypass/injector harness before any primary run |
| `PUB-ME-E3` restart sufficiency | PUB-ME | primary | READY_FOR_SCREENING | select benchmark cases with/without prior retry and instantiate manifest |
| `PUB-ME-E4` semantic-successor evidence | PUB-ME | primary | READY_FOR_SCREENING | ME-S5 frozen as semantic-successor Case B; freeze exact unrelated-change Case A from ME-S6 before detailed extraction |
| `PUB-ME-E5` qualification-surface analysis | PUB-ME | supporting | DESIGNED | define repository-derived surface metrics; no person-hour claims |
| `PUB-ME-E6` extensibility cases | PUB-ME | supporting | READY_FOR_SCREENING | extract solver-seam and groundwater-seam dependency evidence |
| `PUB-SQ-E0` contract/fail-closed | PUB-SQ | prerequisite/supporting | COMPLETE | `PUB-SQ-E0-0001` completed under manifest control; continue with SQ-E1 common-domain/reference design, not additional post-hoc E0 cases |
| `PUB-SQ-E1` common-domain equivalence | PUB-SQ | primary | COMPLETE | six-material P2E10 broad E0 matrix executed against independently frozen P2E09 Reference-only thresholds; retain as observed primary evidence |
| `PUB-SQ-E1X` material-axis extension | PUB-SQ | primary | BLOCKED | P2E11/P2E11R show that the original {0.65,0.85,0.98} extension design has no complete 30-material Reference domain at any preregistered temporal level. Do not execute RossFast on that design. |
| `PUB-SQ-E1D` common material state domain | PUB-SQ | supporting/domain construction | COMPLETE | P2E13 Reference-only scan across all 36 materials found nine complete tested Se levels, 0.65 through 0.96; frozen rule selected 0.65, 0.85 and 0.96 as future anchors. |
| `PUB-SQ-E1T` 36-material threshold freeze | PUB-SQ | prerequisite to new confirmatory extension | COMPLETE | P2E14 froze fifteen Reference-only thresholds over 216 valid cases at Se={0.65,0.85,0.96}; no RossFast extension discrepancy was inspected before the freeze. |
| `PUB-SQ-E1P` material-axis confirmatory holdout | PUB-SQ | primary | COMPLETE | P2E15 executed 180 previously unobserved extension-material cases under P2E14 thresholds: 180/180 admissible, 0 route-invalid, 0 discrepancy-fail. Scope remains the fixed solver-seam common domain only. |
| `PUB-SQ-E2` admissibility boundary | PUB-SQ | primary | DESIGNED | P2E10 established WETTING as a clean known production-envelope exclusion; separate inside/boundary/outside probing still requires its own preregistration |
| `PUB-SQ-E3` equal-error cost | PUB-SQ | primary | BLOCKED | accuracy thresholds + stable `REF-HIGH` required first |
| `PUB-SQ-E4` trajectory accumulation | PUB-SQ | primary | DESIGNED | choose common-domain forcing sequences after SQ-E1 screening |
| `PUB-SQ-E5` expanded scientific domain | PUB-SQ | future | BLOCKED | requires separate RossFast domain qualification |
| `PUB-GC-E0` interface conservation | PUB-GC | prerequisite/supporting | COMPLETE | `PUB-GC-E0-0002` completed under manifest control on the exact F-VQ87 postimage; do not add post-hoc E0 cases; proceed to GW-A and GC-E1 design |
| `PUB-GC-E1` same-origin replay | PUB-GC | primary | COMPLETE | frozen held-out primary executed once at `9363126...`, workflow `35287247968`, immutable artifact retained |
| `PUB-GC-E2` whole-window vs terminal flux | PUB-GC | primary | READY_FOR_SCREENING | terminal-flux comparator qualified at `188c863...`; materialize two new mechanism cases and freeze their inputs/windows before primary execution |
| `PUB-GC-E3` window convergence | PUB-GC | primary | DESIGNED | GC-REF-A root/reconstruction oracle qualified at `4fc8f6e...`; exact stress-case fingerprints/window ladders and converged replay comparator remain to be frozen |
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
3. `PUB-GC-E0`: complete; no further post-hoc E0 screening cases are added;
4. `PUB-GC-E6`: re-express bounded N:1 conservation cases under publication manifests;
5. `PUB-SQ-E0`: complete; no further screening cases are added post hoc; the family hands off to SQ-E1 reference/common-domain design.

These are primarily screening/foundational tasks. They should not be mistaken for final primary publication evidence.

### Tranche B — reference-construction preparation

In parallel:

- `PUB-SQ-REF-HIGH`: define the refinement procedure and stability criterion;
- `PUB-GC-GW-A`: specification frozen in `PUB-GC_GW-A_SPECIFICATION.md`; implement and independently qualify the research-only reservoir before E1 preregistration;
- `PUB-GC-GC-REF`: define the strict coupling reference procedure after the qualified GW-A execution surface exists;
- shared publication telemetry serialization: define before primary matrices are frozen.

No primary claim run should begin until the relevant definitions and implementation prerequisites are frozen.

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

### 2026-09-17T18:34:20Z — PUB-GC-E0 replacement preregistered

- controlling manifest commit: `71b7904a3ddee39c7e3a92c5f1dc23d2feaeaafe`;
- prerequisite satisfied: exact independent F-VQ87 authority, runner blob and oracle-test blob frozen before execution;
- next permitted action at that boundary: execute `PUB-GC-E0-0002` unchanged on the pinned F-VQ87 postimage;
- chronology note: the manifest's internal `created_utc` field was inaccurate; Git commit time is the authoritative preregistration boundary and is preserved in the result receipt;
- cross-publication effect: none; this remains PUB-GC supporting evidence and does not establish current-canonical generalized runtime qualification.

### 2026-09-17T18:36:26Z — PUB-GC-E0 replacement screening completed

- controlling manifest commit: `71b7904a3ddee39c7e3a92c5f1dc23d2feaeaafe`;
- result receipt commit: `218c579d155887423343c0c5daef95a5f67a182c`;
- execution: GitHub Actions run `35259757727`, job `105332222414`, research head `b3f33f031bcf642e2cca3ecfb6d6ac1983257aab`;
- prerequisite satisfied: manifest-controlled independent interface-semantics screening completed on the pinned F-VQ87 postimage;
- admitted scope: bounded F-GC25 interface conservation, rollback, action/reaction and fail-closed topology/origin screening on the exact qualified postimage;
- next permitted action: define and freeze GW-A plus the GC-E1 history-contaminated diagnostic comparator and GC-REF reference procedure before primary replay/convergence runs;
- cross-publication effect: none; no ME, SQ, RC or SG primary claim is inherited, and MODFLOW/window-accuracy claims remain untested.

### 2026-09-17T21:01:45Z — PUB-GC GW-A component decision frozen

- scientific specification commit: `b6800d1337c2101b39d1c07e45ee808a35711926`;
- decision receipt commit: `9ab529a7d905f73b27513320dfdac537339b90e8`;
- reviewed historical fixture: `F-GC21@1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f`, source blob `d3cd07965f6fc0d0628557b18d65f3bbc9396888`;
- decision: the F-GC21 dummy remains a transactional qualification test double and is not admissible as `GW-A`, because its returned head is scripted rather than derived from a physical storage/exchange state;
- prerequisite newly satisfied: GW-A scientific equation, signs/units, transactional state semantics, diagnostic history-contamination boundary and minimum component qualification are frozen before implementation or E1 execution;
- next permitted action: implement and independently qualify the research-only GW-A component and diagnostic origin-policy harness; do not preregister or execute a primary E1 run until those prerequisites are green;
- cross-publication effect: none; no MODFLOW, production-backend, ME, SQ, RC or SG primary claim is created.


### 2026-09-18 — Five-paper manifest reconciliation

- `PUB-ME`: the prior production post-solver rollback result at `7e13915...` is retained as design/harness evidence and is not relabelled as prospective B0/B1 primary evidence. The causal B0/B1 comparison is frozen in `manifests/PUB-ME-CONFIRMATORY-FREEZE-v1.yaml`; primary execution remains blocked on the research-only bypass/injector harness.
- `PUB-SQ`: P2E09 independently froze Reference-only E0 thresholds before the broad P2E10 candidate matrix. P2E10 then attempted all 54 preregistered cases: 36 paired-valid admissible, 18 RossFast-route invalid, with all and only WETTING cases outside the current production forcing envelope. The next confirmatory material-axis extension is frozen separately over the remaining 30 F-ROSS13 materials and must repeat Reference-only threshold construction before any new RossFast discrepancy execution.
- `PUB-GC`: held-out E1 primary workflow `35287247968` completed successfully on exact head `936312659522fe4cacfd349b146d173caa07e5ab` with immutable artifact digest `sha256:0370c5a17033d789e60576a4a0253a8edf3c50dba1b4ab4244a468fa05ccfab6`. The E2 terminal comparator subsequently qualified at `188c863...`. GC-REF-A workflow `35288524091` completed successfully at `4fc8f6e...`, artifact digest `sha256:a6caaa3f32b2def358d8760fc86d073e423688ca47b35e09b775e7228a3d6136`. GC-REF-A is reference infrastructure only and does not retroactively create H2/H3 primary evidence.
- next permitted programme action: materialize the missing ME B0/B1 research harness, execute the SQ 30-material Reference-only extension calibration, and materialize two new GC transient mechanism cases without inspecting comparative method outcomes.

### 2026-09-18 — PUB-SQ material-axis extension blocked before candidate execution

- P2E11 execution branch: `work/pub-p2e11-reference-material-extension-calibration`, result head `e8cd1f363798e5c0a0df586a5f509cd5667bf956`;
- frozen schedule: 0.0064 day coarse versus 0.0032 + 0.0032 day refined Reference;
- outcome: 176/180 Reference pairs valid, four invalid;
- invalid cases: B02/Se=0.98 and B05/Se=0.98 under both DRYING and NOMINAL;
- P2E11D1 fixed-schedule diagnosis: all four solver trajectories converged and passed the hard integrated-mass gate; the blocking predicate was the declared common pressure-head domain, with B05 also outside the strict theta domain;
- candidate firewall preserved: no new RossFast numerical solver execution occurred and no extension threshold was frozen;
- interpretation: the six-material E0 calibration domain does not transfer unchanged to the full material axis;
- next permitted action: a separate Reference-only common-material-domain construction study. It must be labelled exploratory/supporting and cannot retroactively make P2E11 complete.

### 2026-09-18 — PUB-SQ common 36-material state domain constructed

- P2E11R retained all 180 original extension cases across the five preregistered temporal levels and found no complete Reference domain; best level remained 0.0064 day with 176/180 valid;
- P2E11D1 diagnosed the persistent blocker as shared state-domain transfer, not Reference nonconvergence or hard mass failure;
- P2E13 was therefore preregistered as a separate Reference-only exploratory/domain-construction study, with all 36 materials, DRYING/NOMINAL forcing, fixed 0.0064 versus 0.0032+0.0032 schedule, and a frozen 13-level Se grid;
- P2E13 workflow `35289924640`, job `105430331989`, execution head `fb56ccc594d471542c8e06439da31a9c2c43ac1f`, completed successfully with O0/O2-identical output `sha256:6e842ee99ec722678aeaf99143e80eb7340488dc393ab8dae0b31f31ab9b1bce`;
- complete 36-material x two-forcing levels are Se = {0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.92, 0.94, 0.96}; Se=0.98 remains outside the common tested domain and lower levels 0.50-0.60 are also incomplete under the fixed schedule;
- the preregistered anchor rule selects Se = {0.65, 0.85, 0.96};
- candidate firewall preserved: RossFast was not executed and no scientific discrepancy threshold was frozen;
- next permitted action: a separate Reference-only threshold freeze on those three anchors across all 36 materials and both retained forcing classes.

### 2026-09-18 — PUB-SQ 36-material Reference threshold surface frozen

- P2E14 branch: `work/pub-p2e14-reference-common-material-threshold-freeze`, result head `e680334ba1e8352db8d980fa8723ac31a279f636`;
- workflow `35290229184`, job `105431262138`, O0/O2-identical output `sha256:6bbef0ef88b97624f798d8d4da2d14417783465f125f4983830cd6adbacc4d94`;
- all 216 Reference pairs were valid at Se={0.65,0.85,0.96};
- exactly fifteen thresholds were frozen as the per-Se maximum Reference coarse-versus-two-half self-disagreement across all 36 materials and both retained forcing classes, with factor 1.0 and no application floor;
- candidate firewall preserved: no new RossFast extension discrepancy was inspected before the threshold authority was persisted;
- next permitted action: execute only the separately preregistered 30-material confirmatory holdout.

### 2026-09-18 — PUB-SQ material-axis confirmatory holdout completed

- P2E15 preregistration froze 30 previously unobserved extension materials x Se={0.65,0.85,0.96} x {DRYING,NOMINAL}, exactly 180 cases, against immutable P2E14 thresholds;
- the first workflow attempt `35290429228` stopped before scientific execution because of an obsolete authority-variable name; no case ran and no threshold or matrix changed;
- corrected authority-only run `35290525541`, job `105432153537`, execution head `171e6f824899b68403d5eb293672b68f79ee1700`, completed with O0/O2-identical output `sha256:db02085fed1c85504de16fb285a396f52cb163589e91f8b578ad17997ae8f8c8`;
- scientific outcome: 180/180 paired-valid admissible; 0 discrepancy failures; 0 Reference invalid; 0 RossFast invalid; 0 both-invalid;
- each Se stratum was 60/60 admissible and every material was 6/6 admissible;
- worst non-storage threshold fractions were 0.197 for D_h_inf, 0.219 for D_h_rms, 0.248 for D_theta_inf and 0.285 for D_theta_rms; D_storage touched exactly 1.0 times its inclusive frozen machine-scale envelope in one retained boundary observation;
- admitted scope is only the fixed 0.0016-day solver-seam common domain. WETTING, Se=0.98, transaction-level equivalence, heterogeneous profiles, root sinks, groundwater coupling and performance remain outside this result;
- next permitted action: preregister PUB-SQ-E2 admissibility-boundary probing. No retuning of E1 thresholds is permitted.

## Register update rule

Whenever a run family changes status, record:

- date/time;
- controlling commit;
- prerequisite newly satisfied or invalidated;
- next permitted action;
- whether the change affects another publication line.

The register should describe readiness, not rewrite past chronology.
