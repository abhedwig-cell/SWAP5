# F-PE-ELASTIC60 — state-stratified independent budget bridge result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic60-state-stratified-budget-bridge`

Qualified postimage:
`6cd1fc329b94366cf2c6218fbf117934eb289621`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36700621041`

Job:
`109838941763`

Conclusion:
SUCCESS.

## Question

Can one multiplicative defect-indicator scale per exact P2E09 effective-
saturation stratum simultaneously satisfy:

1. realized-error conservatism:
   `H_INF <= alpha(Se) * Binf`;

2. independent P2E09 budget compatibility:
   `alpha(Se) * Binf <= T_h(Se)`;

and then survive blind material holdout?

## Frozen split

Training:
- B01;
- B12;
- O01.

Holdout:
- O05;
- O14;
- O18.

All exact P2E08:
- Se = 0.65, 0.85, 0.98;
- DRYING, NOMINAL, WETTING;
- dt = 0.0064 day;
- two half steps = 0.0032 + 0.0032 day;
- bottom mode 2;
- real stationary accepted history.

P2E09 limits and the train/holdout split were frozen before execution.

## Training interval construction

For each Se:

`L = max_training(H_INF / Binf)`

`U = min_training(T_h / Binf)`.

A multiplicative bridge can exist only if:

`L <= U`.

When feasible, the preregistered alpha is:

`sqrt(L*U)`.

## Se = 0.65

Training interval:

- L = `0.008287051303625283`;
- determining lower case:
  B01 / DRYING;
- U = `0.016280023892754958`;
- determining upper case:
  B01 / WETTING;
- interval width U/L = `1.96451`.

The training interval is feasible.

Frozen training alpha:

`0.01161522247843345`.

However, blind holdout fails realized-error conservatism in all three O05
forcing cases:

- O05 / DRYING:
  observed H_INF = `0.00226163508 cm`;
  alpha*Binf = `0.00204731839 cm`;
  realized/bound = `1.10468`.

- O05 / NOMINAL:
  realized/bound = `1.10458`.

- O05 / WETTING:
  observed H_INF = exactly the frozen P2E09 Se=0.65 envelope
  `0.002329984405367469 cm`;
  realized/bound = `1.10447`.

No Se=0.65 holdout budget-upper failure occurred.

Thus the scale is too small to remain a conservative realized-error envelope on
held-out O05.

## Se = 0.85

Training interval is already empty:

- L = `0.03748895088658713`;
- lower-defining case:
  O01 / DRYING;
- U = `0.03748001035809874`;
- upper-defining case:
  O01 / WETTING.

Relative overlap deficit:

`L/U - 1 = 2.3854e-4`.

Therefore no single scalar alpha can simultaneously satisfy both training
constraints even before holdout.

The deficit is numerically small, about 0.024%, but it is a real preregistered
constraint conflict and is not repaired post hoc.

## Se = 0.98

Training interval is also empty:

- L = `0.18492054235850955`;
- lower-defining case:
  B01 / WETTING;
- U = `0.17418727419215477`;
- upper-defining case:
  O01 / WETTING.

Relative overlap deficit:

`6.1619e-2`.

This is a material conflict, not a roundoff-scale overlap issue.

## Qualification

- exact P2E08/P2E09 54-case domain reproduced;
- stationary accepted-history semantics preserved;
- defect indicator AVAILABLE;
- O0/O2 identity passed;
- no src/** or reference/** changes.

Scientific outcome:

`FALSIFIED_EMPTY_TRAINING_INTERVAL`

because two of three Se strata have no admissible scalar bridge.

The otherwise-feasible Se=0.65 stratum additionally fails blind realized-error
holdout in three O05 cases.

## Interpretation

ELASTIC58/59 showed that the ELASTIC54 global alpha cannot be transferred
directly into the independent P2E09 budget domain and that bootstrap history is
not the cause.

ELASTIC60 now shows that merely stratifying the scalar scale by effective
saturation is still insufficient.

The failure is structural:

- at Se=0.85 and 0.98, different material/forcing cases demand mutually
  incompatible lower and upper alpha bounds;
- at Se=0.65, a training-feasible scalar does not generalize to held-out O05.

Therefore the next step should not be finer scalar stratification by material or
forcing unless an independent physical reason exists.

That route would increasingly memorize the calibration bank rather than produce
a portable temporal indicator.

## Decision

Classification:

`QUALIFIED_STATE_STRATIFIED_SCALAR_BUDGET_BRIDGE_FALSIFICATION`.

No production temporal budget or F-CI14 numeric profile is admitted.

The next bounded research direction should evaluate a more direct head-space
quantity from the defect solve itself, rather than converting the conservative
mass-norm Binf through empirical scalar factors.

A natural candidate is the infinity norm of the tridiagonal defect correction:

`D_INF = max_i |delta_i|`.

This quantity has head units directly and avoids the potentially very
conservative conversion

`Binf = bounded_M_norm / sqrt(min_mass_weight)`.

It must be evaluated research-only against both realized H_INF and the
independent P2E09 envelopes before any admission claim.
