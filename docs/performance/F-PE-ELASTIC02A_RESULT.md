# F-PE-ELASTIC02A — Staringreeks 2018 characterization result

Date: 2026-09-29

Status: CHARACTERIZATION_RECORDED_HOLDOUTS_STILL_CLOSED

Workflow: `36519292454`
Job: `109248411392`
Conclusion: PASS

Source authority:
`docs/performance/evidence/F-PE-ELASTIC02_STARINGREEKS_2018.csv`

External original:
`staringreeks/Data/staringreeks_2018.csv`
SHA-256 `ed2e47bcacdbb6e5fe18eb4f712c3ead996f26f97d647fa550dafd8683d64494`.

## Population

Static descriptors were computed for all 36 official Staringreeks 2018 materials.

Dynamic WET/POND characterization used the 24 preregistered characterization materials only.

The 12 frozen material holdouts remained closed:
B03, B06, B09, B15, B18, O01, O04, O07, O10, O13, O16, O18.

## Near-saturation contrast

At ELAS = 1e-6, the largest `ELAS / C_native(-0.001 cm)` values are:

1. O05: 676.3
2. O01: 8.48, frozen holdout
3. O14: 1.21
4. O03: 0.189
5. B01: 0.132

The remainder of the population is below 0.075.

This confirms that O05 is an extreme constitutive outlier in the official 2018 parameter population, not merely in the earlier repository archetype bank.

## Exact-parameter O05 reversal

A critical result is that O05/POND changes solver classification when exact official parameters replace the rounded repository archetype values.

With the earlier rounded archetype:
- ELAS-off Reference converged;
- ELAS = 1e-6 failed at dtmin.

With exact official Staringreeks 2018 parameters:
- ELAS-off Reference fails at dtmin;
- ELAS = 1e-6 converges;
- converged ELAS work index = 268.

Therefore the direction of the O05 numerical response is not robust to small parameter rounding.

Classification:
`O05_POND_NEAR_SOLVER_BIFURCATION_PARAMETER_PRECISION_SENSITIVE`.

The robust conclusion is not "ELAS worsens O05". The robust conclusion is that O05's extreme near-saturation derivative contrast places the case close to a solver-path bifurcation where small constitutive parameter changes can switch convergence class.

## Dynamic characterization

For the 23 POND materials where both ELAS-off Reference and ELAS=1e-6 converged:

Association of log10 near-saturation contrast R with deterministic work reduction:
- Pearson approximately 0.674;
- Spearman approximately 0.650.

Association of log10 R with absolute storage redistribution:
- Pearson approximately 0.581;
- Spearman approximately 0.666.

Association of log10 R with maximum terminal head change:
- Pearson approximately -0.279;
- Spearman approximately -0.360.

Thus R is moderately informative for numerical-work response and storage redistribution, but it does not explain the magnitude of terminal head changes.

## POND work response

Largest deterministic work reductions among comparable characterization materials:

- O14: 39.5%;
- B01: 32.3%;
- O06: 21.6%;
- O03: 19.4%;
- O02: 18.9%;
- B02: 17.1%;
- B05: 14.5%;
- B07: 12.2%;
- O08: 12.2%;
- O09: 11.6%.

B13 is a counterexample:
- POND work changes from 156 to 176;
- ELAS therefore increases deterministic work by about 12.8%.

No universal speed-improvement claim is supported.

## Physical response

Several materials show large terminal head changes even when R is modest.

Examples:

- B13/WET: top about -3.28 cm, mid about -10.91 cm, bottom about -11.24 cm;
- O14/WET: top about -0.505 cm, mid about -3.61 cm, bottom about -5.21 cm;
- O09/POND: maximum terminal-head change about 2.64 cm;
- O12/POND: maximum terminal-head change about 2.96 cm;
- O15/POND: maximum terminal-head change about 1.98 cm;
- B14/POND: bottom-head change about 2.08 cm.

This confirms the F-PE-ELASTIC01H scope refinement: physical impact requires a state/exposure descriptor in addition to a soil constitutive descriptor.

## Interpretation

The evidence supports three separate concepts:

1. **ELAS as physical soil parameter**
   ELAS belongs to saturated storage physics and should be owned by the soil/material parameter authority.

2. **Near-saturation contrast as numerical-risk descriptor**
   `ELAS / C_native` helps explain solver sensitivity near h=0 and identifies O05 as an extreme precision-sensitive case.

3. **Saturation exposure as physical-impact descriptor**
   Total head and flux effects depend on how much of the profile enters the ELAS-active saturated domain and for how long.

A soil-driven ELAS parameterization must not be selected solely because it improves solver work.

## Scientific boundary

The Staringreeks MvG parameters describe retention and conductivity. They are not, by themselves, direct measurements of porous-medium compressibility.

Therefore this workunit does not fit ELAS as an empirical function of Alpha, Npar, Lambda or Ksfit yet.

The next workunit shall first establish the physical definition and defensible soil-property predictors for specific elastic storage, then determine whether available Dutch soil data can support such a mapping.

The 12 dynamic material holdouts remain closed.
