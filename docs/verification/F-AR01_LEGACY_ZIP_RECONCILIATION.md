# F-AR01 — Legacy ZIP reconciliation

Date: 2026-09-16

Status: **RECONCILED / FOLLOW-UP WORK REMAINS**

## Scope and authority

This work unit reconciles the legacy SWAP 4.3.1 packages recovered from the earlier audit against the current SWAP5 corrected-reference/governance state. It does not apply any legacy patch and does not modify SWAP5 production source.

Canonical authority at reconciliation start:

`integration/f-ci-canonical@6531dae99e5f1cc0cd6d4fadc5c633f0ccece404`

Current corrected legacy reference remains **B1.11**, with source-manifest SHA-256:

`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

Classification used below:

- `AL_VERWERKT`: current authority already contains the qualified intended correction/evidence outcome;
- `DEELS_VERWERKT`: part was consumed, but reusable/open material remains;
- `NOG_OPEN`: bounded follow-up is required before admission or migration;
- `ALLEEN_EVIDENCE`: useful evidence/test material, not itself an admissible production patch;
- `ACHTERHAALD_ALS_BUNDEL`: individual contents have been split/superseded and the aggregate patch must not be applied;
- `NIET_ADMISSION_READY`: scientific/numerical qualification is incomplete or the item is a model/performance choice rather than a corrected-reference bug fix.

## Recovered packages

| Package | ZIP SHA-256 | Classification | Reconciliation result |
| --- | --- | --- | --- |
| `SWAP_4.3.1_E7_SW011_upstream_package (1).zip` | `97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac` | `AL_VERWERKT` | Exact E7 provenance recovered, current-B1 transform qualified, admitted as SWAP-011 / B1.11. |
| `SWAP_4.3.1_complete_testbank.zip` | `af6af725b986b084601483b4ad5bf05ea87557c7248b9ddc98bc7928204553f7` | `DEELS_VERWERKT` + `ALLEEN_EVIDENCE` | Exact B0 hydraulic preimages were used for SWAP-011. Remaining hydraulic/tillage/full-model assets are historical reusable evidence and are not yet imported as a coherent current testbank. |
| `SWAP_4.3.1_patch_proposal.zip` | `d534deb260e1844a7ce80a06e1d8dc48c59ce5319442b648a2193958ff9d8e1a` | `ACHTERHAALD_ALS_BUNDEL` | Most defects were later isolated and admitted individually. Tillage SWAP-003 and SWAP-004 remain explicitly unadmitted. The broad patch must never be applied wholesale to current B1. |
| `SWAP431_oxygenstress_WFT300_package_for_Marius.zip` | `614b5796fa5de2c03ec6281c95aff170b6d5a9ca853eb0019f49d052946385cb` | `NOG_OPEN` / `NIET_ADMISSION_READY` | Three separable performance changes. They are not SWAP-007 and are not part of current B1. WFT300 is an opt-in numerical optimisation, not a B1 bug fix. |
| `SWAP_4.3.1_ponding_jacobian_patch_for_Marius.zip` | `e0403c4387742cc9a6819729d80b09ba3175579cedf3ae8ed47030cedc930d07` | `NOG_OPEN` / `NIET_ADMISSION_READY` | Contains two confirmed audit findings for `headcalc.f90`/`boundtop.f90`, but its own handover explicitly says the core patch is not yet a complete production-qualified patch because restoring the Jacobian changes timestep acceptance. |
| `SWAP_4.3.1_verification_framework_extended.zip` | `199f3d1d607255a813bb023c5741de17eacb173c2537a56bfa214ad2827b0fca` | `DEELS_VERWERKT` + `ALLEEN_EVIDENCE` + `NOG_OPEN` | Contains valuable analytical gates and a 34-item historical issue register. The register is partly superseded by B1.11 and partly contains findings that have not yet been reconciled into current authority. |

The supplied canonical distribution `SWAP_4.3.1(1).zip` has SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and remains B0 evidence, not a change package.

## Broad patch proposal: exact disposition

The embedded broad patch in `SWAP_4.3.1_patch_proposal.zip` is byte-identical to the copy in `SWAP_4.3.1_complete_testbank.zip`; its SHA-256 is:

`37355caa74eeab8e51377eab052dc3350243acfded63fab47a17e669618000ea`

Its nine modified source files combine multiple independent decisions. Current disposition is:

| Historical proposal content | Current disposition |
| --- | --- |
| `macropore.f90` non-conformable assignment | `SWAP-001` — admitted B1 |
| `tillage.f90` start-date/event-pointer logic | `SWAP-002` — admitted B1.10 |
| `tillage.f90` `PCLAY=0` division issue | `SWAP-003` — **NOG OPEN**, current ledger says `CONFIRMED_UNFIXED` |
| `tillage.f90` tillage-type indexing | `SWAP-004` — **NOG OPEN**, current ledger says `CONFIRMED_UNFIXED` |
| `MOD_cropdevelopment.f90` bounds issue | `SWAP-005` — admitted B1 |
| `MOD_meteo.f90` sentinel/initialisation dependence | `SWAP-006` — admitted B1 |
| `oxygenstress.f90` Newton quotient overflow | `SWAP-007` — admitted B1 |
| `tridag.f90` consumed `INTENT(OUT)` arrays | `SWAP-008` — admitted B1 |
| PDI vapour-head sign in `WC_K_models_04_11.f90` | `SWAP-009` — admitted B1 |
| model-7 capacity algebra in `WC_K_models_04_11.f90` | `SWAP-010` — admitted B1 |
| numerical generic `dK/dh` reference prototype | superseded by exact qualified E7 implementation; `SWAP-011` admitted B1.11 |
| generic `prhead` inverse proposal | isolated/requalified as `SWAP-012` — admitted B1.9 |
| PDI HA/H0 input guard | `SWAP-013` — admitted B1.8 |

Conclusion: the broad patch is useful provenance/evidence, but is **not an admissible current patch object**.

## Oxygen-stress / WFT300 package

The package contains three intentionally separable changes:

1. remove a duplicate second `QROMBD` water-film integration;
2. exact early return when maximum respiration already proves no oxygen stress;
3. optional `SWWFTMETHOD=1` 300-point log-space lookup, with legacy Romberg as default.

The combined historical diff modifies `oxygenstress.f90` and `MOD_cropdevelopment.f90`.

Disposition:

- changes 1 and 2 are **performance candidates**, not current B1 corrections; they require a current-authority residual patch plus qualification before any migration;
- change 3 is explicitly a different numerical integration method. It remains an **opt-in numerical/model-execution optimisation**, not a corrected-reference bug fix;
- the packaged patched `oxygenstress.f90` is based on the historical source line and still contains the old unguarded `fi/fi_a` Newton update. Therefore the packaged source must **not** replace current B1/SWAP5 source wholesale, because that would regress already-admitted SWAP-007 semantics;
- package evidence reports material speed gains and good stable-case agreement, but also identifies sensitive profiles with pre-existing Richards nonconvergence and recommends operational/Intel verification before defaulting the lookup.

Next permitted action: a dedicated performance work unit that derives the residual transformations against current authority and qualifies changes 1 and 2 independently; WFT300 must remain a separately switchable decision surface.

## Ponding / top-boundary Jacobian package

The package's `SHA256SUMS.txt` was rechecked locally: all 30 listed files match their recorded SHA-256 values.

Core patch SHA-256:

`101cd0edd9e22f494582b5536cd82ccd849d2f881c20cda3cf224f2a63e4e1ee`

It changes exactly:

- `boundtop.f90`;
- `headcalc.f90`.

The package separates two findings:

1. incomplete top-boundary Jacobian on a deliberately bounded `SWDRA=1`, `RSROEXP=1` path;
2. timestep-dependent branch selection before the existing analytical linear-runoff solution.

The included finite-difference check supports the Jacobian derivation, but the package itself explicitly records that the combined core patch is **not production qualified**. Correcting the Jacobian makes Newton converge much faster and therefore allows much larger accepted timesteps; the wet-transition example changes runoff from `0.24810` to `0.22845 cm` while dramatically reducing steps/iterations. This makes timestep policy a separate scientific/numerical decision rather than something that may be smuggled into a bugfix.

Current B1.11 contains no ponding correction and explicitly retained `headcalc.f90` unchanged through SWAP-011 admission. Therefore this package is **NOG OPEN**, not already processed.

The two files under `experimental/` are `RESEARCH_ONLY` and are excluded from admission.

Next permitted action: split the two core findings into separate qualification surfaces, preserve existing timestep policy during correctness qualification where possible, then decide any transition/timestep controller as a separate model/numerical-policy work unit.

## Extended verification framework

This package is primarily verification/evidence, not a patch. High-value assets include:

- 12 steady-state water cases against an independent Darcy/Richards reference; package status: hard release-gate candidate;
- 15 steady-state solute cases; analytical profile is useful, but the 2021 historical RMSE table remains informational because the original historical test directory/executable was not recovered;
- 12 Srivastava-Yeh/Gardner transient cases; package status: hard analytical release-gate candidate;
- automatic `.bal`/`.blc` checks over 20 balance periods;
- Basha (1999) published targets only; exact run is explicitly blocked pending the original adjusted parameters/input.

Representative exact package paths such as `tests/steady_state_water` and `tests/srivastava_yeh_homogeneous` are not present as such in the current canonical repository. These tests therefore remain candidates for deliberate test-architecture import, not evidence that they are already part of CI.

### Historical issue-register reconciliation

The package issue register has 34 entries. It must not replace current repository authority wholesale because it predates later B1 decisions. For example, it still labels SWAP-011 and SWAP-012 as `BUG_CONFIRMED_SOLUTION_REVIEW`, whereas current authority has admitted them as B1.11 and B1.9 respectively.

Current reconciliation:

- `SWAP-001`, `SWAP-002`, `SWAP-005` through `SWAP-013` except `SWAP-003`/`SWAP-004`: resolved through the current ordered B1 line, with SWAP-011/012 superseding the register's older solution-review state;
- `SWAP-003` and `SWAP-004`: explicitly still waiting for B1 admission review in the current canonical ledger;
- package findings `SWAP-014` through `SWAP-018`: **not represented as admitted corrections in the current B1 manifest** and require fresh current-authority triage before their package classifications can be adopted;
- `TTUTIL-001` through `TTUTIL-003`: separate external-dependency/tooling findings; not part of the B1 patch manifest and require their own provenance/qualification surface;
- `DOC-001` through `DOC-013`: documentation findings. They should be reconciled against the current theory/manual documentation separately; they are not numerical B1 admissions.

For the additional package findings, the safe state is therefore `NOG_TE_RECONCILIEREN`, not silently `FIXED` or `OPEN`: their historical evidence is useful but current canonical state must be checked before mutation.

## Complete-testbank package

This package remains useful, but its roles must be separated:

- **already consumed**: independent B0 hydraulic source preimages used in exact SWAP-011 recovery/replay;
- **historical evidence**: hydraulic consistency results, tillage semantic test, strict grass/macropore failure logs and input fixtures;
- **not a current patch source**: it embeds the same broad proposal patch discussed above, so applying its `patched` source tree would regress/supersede later isolated B1 decisions;
- **not yet integrated as one current test architecture asset**: remaining tests should be selectively imported only after provenance and current-interface adaptation.

## Reconciliation verdict

`ALL_ZIPS_PROCESSED_AS_CHANGES = NO`

`ALL_ZIPS_RECONCILED = YES`

The earlier ZIPs are now accounted for. The important remaining work is not hidden:

1. **SWAP-003 / SWAP-004** remain explicit corrected-reference candidates needing qualification/admission work;
2. **ponding/Jacobian** contains real audit findings but is not admission-ready because correctness repair changes timestep behaviour;
3. **oxygen WFT** contains two performance candidates plus one opt-in numerical optimisation, none of which should be folded silently into B1;
4. **extended verification assets** contain strong analytical tests that are worth importing deliberately;
5. **SWAP-014..018, TTUTIL-001..003 and DOC-001..013** from the historical issue register require a fresh current-authority triage before any claim that they are fixed or still applicable.

## Exclusions

This reconciliation does not:

- modify SWAP5 production source;
- alter the B1 manifest;
- apply any broad historical patch;
- widen tolerances;
- change solver or timestep policy;
- treat research-only timestep controls or WFT300 as bug fixes;
- reclassify package-only findings as current defects without current-authority verification.

## Next permitted action

Proceed in separate bounded work units, in this order:

1. current-authority triage of the still-unreconciled issue-register findings;
2. selective admission of high-value analytical verification tests into the test architecture;
3. SWAP-003 and SWAP-004 qualification;
4. oxygen-stress performance candidates 0001/0002;
5. ponding/Jacobian correctness qualification, with timestep-policy design kept separate;
6. WFT300 only as an explicit opt-in numerical-performance decision surface.
