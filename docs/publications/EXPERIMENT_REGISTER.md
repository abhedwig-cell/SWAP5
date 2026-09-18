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
| `PUB-SQ-E2` admissibility boundary | PUB-SQ | primary | COMPLETE | Upper request-side top-flux boundary: P2E16/P2E17 found 216/216 INSIDE+BOUNDARY admissible and 108/108 OUTSIDE clean fail-closed. E2X then prospectively extended the unobserved surface to the lower request-side top boundary and both bottom-boundary sides: 972 cases, 0 route mismatches, 633/633 interpretable Stage-A-authorized pairs admissible, with 2 authorized cases Reference-unresolved. Proceed to E3 REF-HIGH, not more fixed-flux boundary probing. |
| `PUB-SQ-E3` equal-error cost | PUB-SQ | primary | TIMING_PROTOCOL_AND_BENCHMARK_FROZEN_INFRASTRUCTURE_BLOCKED | P2E23 resolved realized-error matching for all 36 cases; P2E24 froze the admitted-host timing protocol; P2E24A qualified all 106 future timed configurations untimed with O0/O2-identical fingerprint set `sha256:1e86b6da...`. Measured timing is forbidden until MP-8 readiness and full MP-7 host admission pass on the executing runner. |
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

### 2026-09-18 — PUB-SQ REF-HIGH construction blocked before endpoint stability

- P2E18 branch: `work/pub-p2e18-ref-high-construction`;
- final preregistration authority: `8886758ff46878a682a0ab9f57fd58a347b1f49e`;
- qualified workflow: `35292703945`, job `105438767487`, O0/O2-identical output `sha256:fabc9978a010ae242d94a933d14ad87da1039166f5fa7cf9701bfa878f5842b1`;
- route validity over the frozen refinement ladder: 36/36 at 1 substep, 29/36 at 2, 7/36 at 4, and 0/36 at 8, 16 and 32;
- all observed invalid routes fail first as `STATUS_NOT_CONVERGED` / `legacy-reference-retry`;
- no case reaches both preregistered fine endpoint comparisons, so this is not evidence that the 32-substep endpoint itself is temporally unstable;
- RossFast, performance timing and equal-error comparison remain unexecuted;
- next permitted action: separate Reference-only diagnostic of timestep-invariant integrated-balance convergence scaling. P2E18 itself is frozen and is not retuned.

### 2026-09-18 — PUB-SQ Reference policy diagnosed and casewise REF-HIGH qualified

- P2E16C independently reproduced the E2X fixed-step Reference limitation as nonlinear-iteration retry behavior with a non-monotone timestep response; smaller dt did not recover the 0.0016-day horizon;
- P2E16D recovered only 2/5 such cases by raising the nonlinear iteration budget through 64, so REF-HIGH is not reducible to a larger Newton budget;
- P2E18D1 showed that an invariant integrated balance allowance of 1.6e-15 cm per substep materially restores Reference refinement validity but is not universally sufficient;
- P2E18D2 localized the remaining scaled-policy retry events to the total-balance gate on its outcome-informed mechanism set; no tolerance was changed from the D1 policy;
- P2E19 then ran the full six-level, two-policy 36-case causal diagnostic. FIXED_RATE exactly reproduced P2E18 {36,29,7,0,0,0}; INTEGRATED_INVARIANT yielded {36,35,35,36,35,34};
- P2E19 endpoint neutrality passed 72/72 overlapping fixed-versus-scaled comparisons. Fine 8/16/32 stability was available for 34 cases and passed for 33;
- P2E20 separately materialized the casewise Reference authority: 33 `REF_HIGH_QUALIFIED`, 2 route-unresolved, 1 stability-unresolved. The qualified endpoint is the 32-substep Reference state under the frozen integrated-invariant policy;
- RossFast and timing were not executed in P2E18 through P2E20;
- next permitted action: preregister equal-error solver control and work/timing methodology on exactly the 33 qualified cases. No speedup inference is authorized before that freeze.

### 2026-09-18 — PUB-SQ final 36-case REF-HIGH and threshold-control migration

- P2E21 replaced the provisional 33-case P2E20 performance reference with a final 36/36-case REF-HIGH authority using the prospectively defined `REPRESENTATION_BOUNDED_TOTAL` research policy;
- the total-column bound is formula-derived from floating-point representation scale before each solve, uses no empirical safety factor and does not change production Reference tolerances;
- all 36 cases are route-valid at 8, 16 and 32 substeps and pass both unchanged REF-HIGH stability comparisons; the 32-substep endpoint is the final E3 numerical reference;
- P2E21A had already frozen an untimed segmentation ladder {1,2,4,8,16,32}, accuracy targets A1/A2/A3 and least-refined valid-selection rule on the earlier 33-case reference;
- P2E22 migrated those unchanged rules to the final 36-case P2E21 reference: 432 production configurations, 216 selection records and 36 REF-HIGH reconstructions, all O0/O2 identical;
- both REF_PROD and Ross have 36/36 paired availability at all three targets. Under the final reference every solver/case/target selection is N=1;
- the six changed overlapping selection records are exactly cases 4 and 18 across all three targets, where REF_PROD moves from N=2 to N=1 after the reference migration; Ross remains N=1;
- the three newly admitted P2E21 cases 1, 2 and 36 all select N=1 for both production solvers;
- the three accuracy targets therefore collapse completely. A descriptive diagnostic over all route-valid configurations finds only 1/36 cases with any REF_PROD/Ross pair within factor 2 in actual normalized head/theta error;
- interpretation: P2E22 provides **common-threshold-matched controls**, not strict equal-observed-error controls. Timing N=1/N=1 now would not answer H3 as written;
- next permitted action: a separate untimed work-precision matching study using the already qualified representation-bounded Reference refinement policy and a deterministic equal-or-better-error/bracketing rule. Retain all 36 cases and explicit unresolved outcomes. Timing remains forbidden.

### 2026-09-18 — PUB-SQ realized-error matching resolved before timing

- P2E23 branch: `work/pub-p2e23-observed-error-reference-matching`, result head `d05ed330ad3bf033d9a8542fec78e37839233570`;
- workflow `35314767424`, job `105503952798`, O0/O2-identical output `sha256:1a8633e36e76875c454df32b1ca5725af6362c4216ecbefffa6ce136a08fca74`;
- RossFast was frozen at the P2E22 N=1 production route. Representation-bounded Richards was evaluated untimed for every integer N=1..32 in every one of the 36 cases;
- all 1,152 Reference configurations were valid. Thirty-four cases have a true realized-error bracket, two B12/Se=0.65 cases are left-censored at N=1 because Reference N=1 is already more accurate, and no case is unresolved;
- for the 34 bracketed cases, the selected Reference N_hi ranges from 7 to 24. Its normalized head/theta error is 0.868 to 0.998 times the RossFast N=1 error; the last coarser N_lo is 1.001 to 1.148 times RossFast error;
- one case has a two-step bracket because the intermediate N=21 endpoint exceeds the unchanged machine-scale storage gate even though its solver route is valid;
- the matching algorithm never used timing, work counters or closest-ratio optimization;
- next permitted action: preregister paired timing of RossFast N=1 versus casewise Reference N_hi. Execution is blocked until the repository's MP-8 isolated-runner readiness and full MP-7 host-admission gates pass. The two left-censored cases must remain labelled conservative, not strict equality.

### 2026-09-18 — PUB-SQ P2E24 timing protocol and workload frozen, execution blocked on infrastructure

- P2E24 timing branch: `work/pub-p2e24-realized-error-timing`, protocol head `cc1dad6f3fd322044657d36361a8e9d74c3e4026`;
- the initial parallel draft using `ubuntu-latest` and Fortran `CPU_TIME` was corrected **before any timing exposure** because it conflicted with the existing MP performance-governance stack;
- admissible timing now requires runner labels `[self-hosted, linux, x64, swap5-performance]`, MP-8 contract readiness and full MP-7 host admission on the same runner configuration;
- primary timing metric is externally measured child CPU seconds; monotonic wall elapsed is secondary. Ordinary shared-runner timing and Fortran internal clocks are not primary publication evidence;
- primary comparator remains RossFast N=1 versus casewise Reference N_hi. Twenty-four order-balanced measured cycles are frozen per case, with the repository paired-resolution rule and a 5% per-case publication resolution target; no selective reruns or post-hoc pair extension;
- P2E24A branch `work/pub-p2e24a-benchmark-fingerprint`, result head `d6dd6594af4f682672a4021985ff80e531bb14c0`, qualified the exact benchmark workload without timing;
- P2E24A workflow `35316717285`, job `105509858009`: all 106 future timed configurations are executable and the full scientific fingerprint set is O0/O2 byte-identical at `sha256:1e86b6da40eb61d17fa59bdc995b553bd3d0d447d6d13c2c46f2c715a95d95d3`;
- current repository performance readiness remains `INFRASTRUCTURE_PENDING` with `cpu_baseline_established=false`;
- next permitted action is external infrastructure work only: provision/identify the isolated runner, reproduce the 106-configuration fingerprint untimed, pass MP-8 and MP-7, then execute the frozen P2E24 timing protocol exactly once as the primary exposure.




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

### 2026-09-18 — PUB-SQ upper top-flux admissibility boundary qualified

- P2E16 froze the upper-boundary experiment candidate-blind. Its exact request-side top-flux factors were 0.009 x K0 (INSIDE), 0.010 x K0 (BOUNDARY) and 0.011 x K0 (OUTSIDE), with bottom flux fixed at -0.004 x K0;
- P2E16 workflow `35290915120`, job `105433341576`, execution head `ddf4a535743d3abdb1d1eeb8f787ecd843376984`, produced 324/324 valid Reference cases and O0/O2-identical output `sha256:385ed7ded30022d5fef98927bb9d325499af8d983b4057179503c9ba70d3a96d`;
- P2E17 first candidate exposure established the primary route-boundary and inside/boundary discrepancy result. All 108 INSIDE and all 108 BOUNDARY cases were paired-valid admissible; all 108 OUTSIDE cases were RossFast-route invalid; no inside/boundary discrepancy threshold failed;
- a harness correction was then made to enforce the preregistered epistemic rule that OUTSIDE cases are fail-closed probes only, never discrepancy/performance observations;
- corrected hygiene run `35291213606`, job `105434242429`, exact head `00fd77bf9a335fb1b458d203e9ea2a868b5eafc0`, completed O0/O2-identically with `sha256:0c70a32f3743a407f7e9e503cf225ec1804b76ccf132afb05fc76980cbf39910`;
- fail-closed hygiene: 108/108 OUTSIDE rejected cleanly, 0 dirty rejection, 0 unexpected RossFast acceptance, 0 Reference invalid; rejected cases published no candidate state and no typed integrated mass result;
- supported scope is only the tested **upper request-side top-flux boundary** at 0.001 x K0 resolution within the established common state domain. Lower top-flux, bottom-flux, transaction-level, trajectory, heterogeneous-profile, root-sink, groundwater and performance claims remain open;
- next permitted action: PUB-SQ-E3 Reference construction. Freeze a representative case subset and a candidate-blind REF-HIGH stability rule before any equal-error cost or timing execution.


### 2026-09-18 — PUB-SQ full-flux boundary extension reconciled

- central governance alias: `PUB-SQ-E2X`; historical branch-local files retain `P2E16A/P2E16B/P2E16D1` identifiers because a parallel upper-top P2E16/P2E17 line had already allocated those numbers;
- chronology matters: prior P2E17 upper-top candidate exposure started at 2026-09-18T00:25:53Z, while the broader boundary preregistration was committed at 2026-09-18T00:33:45Z;
- therefore the 324 TOP cases at rho={-1.05,-1.0,-0.95}, equivalent on this common state domain to request top flux/K0={0.011,0.010,0.009}, are supporting replication only and are not counted as a new holdout;
- prospectively unobserved extension surface: 972 cases covering TOP rho={0.95,1.0,1.05} and both sides of the BOTTOM boundary;
- Reference-only Stage A: 972/972 Reference-valid; unchanged P2E14 thresholds transferred to 951/972 cases and failed on 21 retained cases;
- candidate Stage B on the new surface: 648/648 inside-or-boundary route-valid, 324/324 outside fail-closed, 0 route mismatches and 0 fallback;
- among 635 Stage-A-authorized route-valid pairs, 633 had a valid fixed-step Reference and all 633 were admissible with 0 discrepancy failures; cases 1220 and 1257 remained Reference-unresolved;
- P2E16D1 diagnosed all five fixed-step Reference-invalid cases as nonconvergence on `legacy-reference-retry`, not state-domain, flux-identity or mass-gate failures;
- controlling checkpoint: `docs/publications/manifests/PUB-SQ-FULL-FLUX-BOUNDARY-EXTENSION-CHECKPOINT_2026-09-18.json`;
- next permitted action: `PUB-SQ-E3` candidate-blind REF-HIGH construction. No further fixed-flux boundary holdout is required before that step.

## Register update rule

Whenever a run family changes status, record:

- date/time;
- controlling commit;
- prerequisite newly satisfied or invalidated;
- next permitted action;
- whether the change affects another publication line.

The register should describe readiness, not rewrite past chronology.
