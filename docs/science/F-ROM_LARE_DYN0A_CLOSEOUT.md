# F-ROM-LARE DYN0A closeout

## Decision

**STANDARD_LARE_PHYSICALLY_COHERENT_AND_RESOLUTION_CONVERGENT_BUT_LOW_DIMENSION_NOT_BROADLY_QUALIFIED**

DYN0A is closed as a bounded fixed-flux dynamics characterization.

This is not an application acceptance, a production-ROM admission, or evidence that LARE is superior to conventional coarse Richards.

## What DYN0A established

### 1. The state and the closure are separate problems

RS1 showed that the three-storage D3 state

`0-140 | 140-150 | 150-160 cm`

is the minimum response-blind state-information candidate in the bounded B01 groundwater laboratory.

D4 adds a `130-140 cm` storage state but did not add measurable state-information value in the RS1 common-cohort response test.

DYN0A nevertheless found a large dynamics difference between D3 and D4.

Therefore:

> a reduced state can retain the relevant predictive distinctions and still be propagated poorly by a coarse layer-averaged closure.

That distinction is now executable evidence rather than a conceptual warning.

### 2. Standard LARE is conservative and equilibrium-consistent in this fixed-flux laboratory

The clean-sheet published LARE closure preserves the explicit layer water ledger.

The equilibrium controls are reproduced to numerical roundoff.

The observed failures are therefore dynamic redistribution errors, not hidden water creation/destruction and not a simple equilibrium offset.

### 3. D3 is not broadly accurate as a dynamics model

For the critical qualified B01 `Se0=0.95 DRY` transient, standard LARE D3 reaches a maximum projected common-layer storage error of approximately 24.52 mm.

The bottom 10-cm storage error reaches approximately 16.78 mm.

This is incompatible with any claim that the RS1-positive D3 state automatically implies a useful three-layer LARE dynamics model.

No absolute application threshold is inferred from these values.

### 4. D4 identifies closure-resolution error

Moving the long-to-local interface upward by 10 cm gives D4:

`0-130 | 130-140 | 140-150 | 150-160 cm`.

For the same critical transient, the maximum common-band storage error drops from approximately 24.52 mm to 6.88 mm, a reduction of about 72%.

Because RS1 found no useful additional D4 state information over D3, this improvement is attributed to closure/discretization resolution rather than missing predictive state.

### 5. The dominant closure error is gradient reconstruction

The MECH1 decomposition shows that the dominant projected interface-flux error comes from reconstructing the hydraulic gradient from a long layer average adjacent to an active interface.

For the pooled high-state D3 cohort:

- total interface-flux RMS error: about 0.452 cm/day;
- gradient-reconstruction component: about 0.338 cm/day;
- conductivity-localization component: about 0.112 cm/day;
- constitutive-averaging component: about 0.0034 cm/day.

The dominant error follows the coarse-to-local interface when that interface is moved in D4.

### 6. Standard LARE converges with vertical resolution

The preregistered nested ladder gives, for the critical `Se0=0.95 DRY` case:

| member | long layer | max common-band error |
|---|---:|---:|
| R3 | 140 cm | 24.523 mm |
| R4 | 130 cm | 6.877 mm |
| R5 | 120 cm | 1.743 mm |
| R6 | 110 cm | 1.106 mm |
| R8 | 90 cm | 0.803 mm |
| R12 | 50 cm | 0.288 mm |
| R16 | 10 cm | 0.0127 mm |

Every adjacent resolution step improves storage fidelity on the common dynamic cohort.

R16 is a no-spatial-reduction control, not a ROM.

The result supports the physical coherence and convergence of the standard closure. It does not identify an application-independent acceptable reduced dimension.

### 7. A nonlinear hydraulic penetration scale has blind mechanistic support

The simple initial-state diffusion length failed blind B14 transfer.

MECH3A therefore selected, before the next blind panel, a forcing-path geometric hydraulic diffusivity scale:

`ell_G = sqrt(D_G * T_pulse)`.

No blind-panel refit was permitted.

MECH3B then tested frozen Carsel-Parrish sand, loam and clay parameters.

The preregistered panel decision is:

**NONLINEAR_SCALE_TRANSFER_SUPPORTED**

The selected path-geometric scale improved all three primary pooled criteria relative to the initial-state local-diffusivity baseline:

| metric | PATH_GEOMETRIC_D | LOCAL_D0 |
|---|---:|---:|
| pooled std ln(lambda) | 0.88585 | 1.05531 |
| between-material mean-ln(lambda) std | 0.50827 | 0.57943 |
| RMS log peak-prediction error | 0.98426 | 1.17038 |

This is genuine blind support because the three materials, constitutive parameters, scale formula and discovery multiplier were frozen before their new Reference responses were generated.

However:

- only 12 WET/DRY cases contribute to the pooled result;
- loam and clay satisfy the per-material minimum;
- sand contributes only one qualified DRY case and no qualified WET case;
- the selected scale still has broad dispersion;
- exact snapped peak-location hits are only 4 of 12;
- the median absolute log prediction error is not improved.

Therefore the scale is retained as a **mechanism and resolution-risk diagnostic**, not as a universal LARE grid rule.

## What DYN0A did not establish

### Equal-dimension coarse Richards

The dynamic D2/D3 coarse-Richards routes could not be numerically qualified under the frozen strict Reference authority, even after the preregistered temporal-refinement ladder.

Therefore:

**no claim that LARE outperforms coarse Richards is authorized.**

### Groundwater exchange under prescribed head

DYN0A fixed the bottom flux externally.

It therefore cannot establish whether LARE predicts drainage, recharge, capillary rise, flux sign or reversal timing correctly when groundwater head is the boundary driver.

That requires a pressure-controlled bottom closure.

### Application acceptance

No absolute GW-D, GW-R, crop, event or profile-research acceptance threshold has been established.

The resolution ladder must not be converted post hoc into a statement such as "R8 is good enough" merely because one error happens to be sub-millimetre in one critical B01 experiment.

### Computational value

No speed claim is authorized before a hydrologically admissible reduced route exists for the target application.

## BC1 is now the primary blocker

The 2021 source gives the bottom Darcy relation and a first-order Taylor expression for the bottom capillary-pressure gradient. For its pressure-controlled groundwater case it then sets boundary conductivity to saturated conductivity because the boundary is a water table.

Thus the source directly supports:

- prescribed bottom flux;
- free drainage;
- the special saturated/water-table pressure boundary.

It does not explicitly validate the fixed-domain case needed for arbitrary unsaturated prescribed pressure head in the SWAP mode-5 groundwater laboratory.

The next primary work unit is therefore:

**LARE-BC1 — prescribed-head bottom-boundary authority and qualification**

The question is deliberately narrow:

> Can the existing source equations be extended, without empirical fitting, to a fixed lower boundary with an arbitrary prescribed unsaturated pressure head, and does that closure reproduce Reference-Richards bottom exchange over the existing groundwater rise/fall and reversal laboratory?

Moving-water-table geometry remains a separate later problem.

## Secondary mechanism question

The positive MECH3B result justifies a later independent test of whether the **full interface-error curve**, not only its peak location, collapses against the dimensionless coordinate `L/ell_G`.

That test must use previously unused materials and may not fit another material-specific multiplier or select a grid threshold from the blind response.

It is secondary to BC1 for groundwater-coupling relevance.

## Final DYN0A status

`STATE_INFORMATION = POSITIVE_BOUNDED_D3`

`STANDARD_LARE_FIXED_FLUX = PHYSICALLY_COHERENT_RESOLUTION_CONVERGENT`

`LOW_DIMENSION_D3 = NOT_BROADLY_DYNAMICS_QUALIFIED`

`D4 = MATERIAL_CLOSURE_RESOLUTION_BENEFIT_BUT_NOT_APPLICATION_ACCEPTED`

`PATH_GEOMETRIC_DIFFUSIVITY_SCALE = BLIND_MECHANISTIC_SUPPORT_WITH_LIMITATIONS`

`EQUAL_DIMENSION_COARSE_RICHARDS_DYNAMIC_COMPARATOR = BLOCKED_CURRENT_AUTHORITY`

`PRESCRIBED_HEAD_GROUNDWATER_EXCHANGE = NOT_YET_AUTHORIZED`

`APPLICATION_ACCEPTANCE = NOT_ADJUDICATED`

`PRODUCTION_ROM_AUTHORIZED = FALSE`
