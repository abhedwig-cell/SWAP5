# F-PE-ELASTIC02A — full Staringreeks ELAS population design

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_FULL36_RESULTS

Prerequisite:
F-PE-ELASTIC02 official source acquisition must validate an exact 36-row Staringreeks 2018 parameter file before this experiment may run.

## Population

Official Staringreeks 2018:
- B01..B18;
- O01..O18.

Previously inspected exploratory seed materials:
- B01;
- B12;
- O05;
- O14.

These four are not independent validation materials in later model selection.

## Frozen material holdout

The following 12 previously unseen materials are reserved before any full-population dynamic result is inspected:

- B03
- B06
- B09
- B15
- B18
- O01
- O04
- O07
- O10
- O13
- O16
- O18

They must not be used to select predictors, thresholds or coefficients for a soil-driven ELAS relation.

The remaining 20 previously unseen materials plus the four exploratory seed materials form the characterization/calibration population.

## Phase 02A1: descriptor-only population map

For all 36 materials compute from the exact official parameter rows:

- WCr, WCs, Alpha, Npar, Lambda, Ksfit;
- m = 1 - 1/Npar;
- 1/Alpha;
- exact B1.10 native C at h = -20, -5, -1, -0.1, -0.01 and -0.001 cm;
- ELAS/native-C ratios at those heads for ELAS = 1e-6;
- exact default-MvG K/Ksat at the same heads.

Descriptor calculation may include holdout materials because it uses only static input parameters and no dynamic ELAS outcome. Holdout labels remain frozen.

## Phase 02A2: dynamic characterization

Before fitting a rule, run only the characterization/calibration population under:

- WET fixture;
- POND fixture;
- ELAS-off Reference;
- ELAS = 1e-6.

Record:
- convergence;
- accepted/rejected attempts;
- nonlinear work;
- runoff;
- ponding;
- terminal top/mid/bottom heads;
- storage;
- water ledger;
- maximum/final saturated-node fraction if instrumentation is available.

The 12 material holdouts remain closed during predictor/rule selection.

## Candidate mechanistic predictors

The initial predictor set is frozen to:

1. log10(ELAS / C_native(-0.001 cm));
2. log10(ELAS / C_native(-0.01 cm));
3. log10(Ksfit);
4. log10(1/Alpha);
5. Npar;
6. WCs-WCr.

No higher-capacity or black-box model is allowed before these simple predictors are assessed.

## Outcome classes

Separate two targets:

### Numerical-risk target
- converged vs dtmin failure;
- work ratio versus ELAS-off Reference.

### Physical-impact target
- runoff/storage redistribution;
- head change;
- saturation exposure.

No single scalar score may combine physical and numerical outcomes.

## Holdout rule

A candidate soil-driven ELAS rule and all thresholds must be frozen before any dynamic result for the 12 reserved materials is opened.

No production admission is authorized by F-PE-ELASTIC02A.
