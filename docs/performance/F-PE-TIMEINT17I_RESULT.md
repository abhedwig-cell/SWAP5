# F-PE-TIMEINT17I result — trust-region model-quality attribution

Date: 2026-09-29

Status:

`TIMEINT17I_MIXED_MODEL_QUALITY`

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36535798615`;
- job: `109299437889`;
- conclusion: SUCCESS.

## Frozen question

TIMEINT17I asked whether the endpoint failures attributed to nonlinear globalization are characterized by sufficiently poor Newton local-model quality to justify opening a trust-region repair.

No solver behavior was changed.

## Coverage

Coverage gate:

PASS.

Audited failing Newton iterations:

`768`

Tested backtracking candidates:

`2078`

Scope:

- routes: FLUX, HEAD, RUNOFF;
- materials: B01, B12, O05, O14;
- modes: TG and KLAG;
- dt levels: 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- process failures: 0.

## Aggregate model-quality result

Selected-factor `rho < 0.25`:

`0.43620`

Selected-factor `rho < 0`:

`0.0`

Full-step `rho < 0`:

`0.49740`

Iterations where a smaller tested factor improves selected rho by >=0.25 while producing positive actual reduction:

`0.0`

Median selected rho:

`0.49117`

Frozen TRUST_REGION_SIGNAL required both:

1. >=25% selected `rho < 0.25`;
2. >=25% iterations rescued by a smaller tested factor with rho improvement >=0.25.

The first condition passes strongly.

The second fails completely.

Therefore:

`TIMEINT17I_MIXED_MODEL_QUALITY`.

## Route / mode decomposition

Poor-model fraction, selected rho < 0.25:

- FLUX / TG: 0.53125;
- FLUX / KLAG: 0.515625;
- HEAD / TG: 0.40625;
- HEAD / KLAG: 0.40625;
- RUNOFF / TG: 0.40625;
- RUNOFF / KLAG: 0.3515625.

Median selected rho:

- FLUX / TG: about 0.0685;
- FLUX / KLAG: about 0.1764;
- HEAD / TG: about 0.6239;
- HEAD / KLAG: about 0.5513;
- RUNOFF / TG: about 0.6001;
- RUNOFF / KLAG: about 0.5931.

FLUX is therefore the clearest poor-model family, and the signal is shared by TG and KLAG.

## Interpretation

TIMEINT17I strengthens the globalization attribution without yet selecting a repair.

Nearly half of full Newton steps have negative rho: the linear model predicts residual-merit reduction but the actual full step increases residual merit.

However, the existing geometric backtracking sequence does not reveal a systematic smaller-factor rescue under the frozen criterion.

That means:

- the local Newton model is frequently unreliable outside its convergence basin;
- simple additional damping along the same Newton direction is not supported as the general repair;
- the evidence does not yet authorize a trust-region radius or Levenberg parameter;
- the problem is shared across TG and KLAG and is therefore not specific to the Thomas-Gladwell temporal method.

## Consequence

Do not open a trust-region repair directly from TIMEINT17I.

Open a separate route/mode/state-scale attribution workunit that can distinguish at least:

1. FLUX-specific poor model quality;
2. HEAD/RUNOFF convergence-contract limitations;
3. whether poor rho correlates with raw pressure-head step magnitude;
4. whether physically defensible nondimensional state scaling collapses those differences;
5. whether the failing direction itself is poor or only its unscaled magnitude is poor.

Any trust-region radius, scaling constant, variable transform, Levenberg parameter or new globalization algorithm requires separate preregistration after that attribution.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No tolerance change.

No MAXIT/MaxBackTr change.

No timestep change.

No physical or dynamic-top event change.

`LEGACY_NUMERICS` remains production default.
