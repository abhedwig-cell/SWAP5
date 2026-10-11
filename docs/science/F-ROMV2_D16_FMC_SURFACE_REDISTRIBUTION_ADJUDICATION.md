# F-ROMV2 D16 FMC surface redistribution adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D16  
**Decision:** **FMC_SURFACE_REDISTRIBUTION_RETAINS_RESEARCH_CANDIDACY**

## Question

D16 tests the atmospheric-side FMC/SMVE branch after D12-D15 established equation, kinematic and finite-volume accounting authority.

The experiment is intentionally narrow:

- homogeneous B01;
- one pre-existing connected-front profile (D14 I_DEEP);
- prescribed infiltrating top flux at 0.10, 0.25, 0.50 and 0.75 of Ksat;
- 16 pulse steps followed by 48 zero-supply hiatus steps;
- 10 s observation/process step;
- zero bottom flux;
- no groundwater front;
- no runoff, ponding, dry-bin activation, ET or root uptake.

The scientific target is vertical redistribution fidelity, not total water balance. Because top infiltration and zero bottom flux are identical by construction, total storage is constrained by conservation and cannot by itself discriminate model quality.

## Authority cleanup

PR #445 is the primary D16 scientific exposure.

Its frozen preregistration blob is:

`ef4d00934e7fbcaefdf9378031b6b4b5bcbb1dbe`.

A later parallel PR #446 defined a materially different surface workload under the same D16 work-unit ID after the primary D16 exposure path existed. It is closed as superseded and carries no D16 scientific authority. Any future use of that alternative design requires a new work-unit ID.

## Staged preflight

The first preflight run detected only a floating-point state-representation issue in falling-slug length after repeated identical Eq.19 translations.

No SWAP trajectory evidence had been generated.

The technical repair changed the state representation from independently accumulated top/bottom endpoints to top plus invariant slug length. It changed no FMC hydrological equation, pulse factor, duration, bin count, process step or decision gate.

The repaired preflight then passed before Reference exposure:

- all four histories absorbed the complete prescribed supply;
- no dry-bin activation, runoff or ponding occurred;
- all falling slugs remained inside the 160 cm column;
- minimum bottom clearance was about **39.75 cm**;
- maximum global finite-volume ledger residual was about **7.11e-15 cm**;
- slug-length drift was zero at reported precision.

## Immutable execution

Primary workflow run **35456435820**, job **105932432291**, executed head

`a223fcd5ea9b4ff642caabf60592bd491a1fe0ca`.

Artifact:

- ID: **10588253110**
- digest: `sha256:52bf33f88f63d70999620ac3a57a02b4137fb9651ef0536a8d9799a20ce1d301`
- hydrological result SHA-256:
  `9a4e0b2f3de6d4bc48e0955d652f18d76e9b2f0200431f646f63f57bfb4f8fda`.

R16 and R2 are each bitwise identical between O0 and O2.

## Integrity

All four histories complete.

Maximum absolute mass residuals:

- FMC: **6.36e-15 cm**;
- R2: **1.42e-14 cm**;
- R16: **2.13e-14 cm**.

All remain far below the frozen **1e-12 cm** hard transaction mass scale.

No clipping, hidden correction or full-order FMC fallback is used.

## Redistribution fidelity

Pooled over all 256 observations:

| metric | FMC | R2 |
|---|---:|---:|
| upper 0-80 cm storage RMSE | 0.008953 cm | 0.009860 cm |
| lower 80-160 cm storage RMSE | 0.008953 cm | 0.009860 cm |
| mapped 16-cell theta RMSE | **0.001140** | **0.032448** |

During hiatus only:

| metric | FMC | R2 |
|---|---:|---:|
| upper 0-80 cm storage RMSE | 0.009506 cm | 0.011290 cm |
| lower 80-160 cm storage RMSE | 0.009506 cm | 0.011290 cm |
| mapped 16-cell theta RMSE | **0.001275** | **0.032321** |

Every preregistered gate passes.

The largest improvement is in resolved vertical profile structure. FMC mapped-profile RMSE is only about 3.5% of the R2 value over all steps and about 3.9% during hiatus.

This is physically consistent with the purpose of the front/slug representation: it retains vertical redistribution memory that is largely erased by two 80-cm Richards cells.

## Important nonclaims

Near-zero total-storage error is not evidence of superior hydrology here. It follows from the matched prescribed top input, zero bottom exchange and conservative accounting.

D16 does not test:

- rainfall-runoff or ponding thresholds;
- dry-bin activation;
- simultaneous groundwater-front interaction;
- arbitrary prescribed SWAP bottom pressure heads;
- ET or root uptake;
- seasonal accumulation;
- live groundwater coupling;
- same-runtime performance.

The R16/R2 research route reattempts nearly every step in this short workload, so these runs must not be used for production-runtime inference.

## Relation to D13

D13 independently retained the FMC groundwater-front branch against R2.

D16 independently retains the surface infiltration/hiatus branch.

The two positive findings are not yet equivalent to a combined model qualification. Their composition can create new interactions:

- surface fronts may meet a groundwater-connected interval;
- falling slugs may merge with groundwater-connected water;
- simultaneous top and lower-boundary forcing may alter flux partitioning;
- finite-volume ledgers must remain exact across branch transitions.

The next workunit should therefore test the **composition of the already qualified branches**, not add new FMC equations or tune the discretization.

## Decision

D16 closes positively as bounded surface-redistribution research candidacy:

`FMC_SURFACE_REDISTRIBUTION_RETAINS_RESEARCH_CANDIDACY`.

D17 may test combined surface forcing plus a fixed groundwater/water-table branch under a separately frozen matched envelope.

D17 must retain:

- 200 bins;
- the existing process-step bound;
- D12-D15 equations/accounting;
- no post-D16 bin/substep/front-law tuning;
- R2 as the physical-reduction comparator;
- purpose-dependent fidelity rather than full Richards identity.

Application acceptance remains unqualified.

Formal speedup remains unqualified.

Production ROM remains unauthorized.
