# F-PE-ELASTIC46 — production-shaped ELAS numerical/performance characterization preregistration

Date: 2026-09-29

Status: PREREGISTERED_OBSERVATION_ONLY

Baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Parent authority:
- `F-PE-ELASTIC05_RESULT.md`;
- `F-PE-ELASTIC09_CLOSURE.md`;
- `F-PE-ELASTIC42_RD_END_TO_END_RESULT.md`;
- `F-PE-ELASTIC45_CLOSURE.md`;
- `F-PE-PROFILE04_CLOSEOUT.md`.

## Question

Now that physically parameterized ELAS can reach prepared production parameters,
what numerical and runtime effect does it have on the production Reference route?

Compare three parameter regimes on the same hydraulic/grid/forcing bank:

1. `OFF`: current default-off ELAS behavior;
2. `FIXED_1E6`: explicit uniform `Ss = 1e-6 cm^-1`;
3. `GENERATED`: the admitted BOFEK/BRO generated prior for the frozen real
   MINERAL profile `90116260`.

This workunit is observational. It must not choose a new default or modify
solver/timestep policy.

## Physical interpretation boundary

ELAS affects the admitted default-MvG constitutive route only for `h >= 0`:

- active: `theta = theta_s + h * Ss`, `C = Ss`;
- inactive: existing saturated numerical-capacity fallback.

The characterization bank must therefore include saturated/ponded states where
ELAS is physically active, plus at least one unsaturated control where the
active ELAS term should not materially alter constitutive behavior.

No result may be interpreted as calibration evidence for `1e-6`.

## Frozen generated-prior authority

Use the admitted frozen source:
- producer run `36550782840`;
- artifact `f-pe-elastic12a4-pdok-atom`;
- SHA-256 `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

Use the already-qualified real MINERAL case:
- `normalsoilprofile_id = 90116260`;
- RD x `179362.75550490862` m;
- RD y `418659.84937244334` m.

Materialize GENERATED through admitted ELASTIC41/44/45-era seams. Do not
reimplement the prior formula in the experiment.

## Frozen experiment bank

Use one 16-node production Reference/default-MvG column geometry derived from
the selected real profile horizons, with the existing qualified generic MvG
hydraulic fixture retained so that ELAS is the controlled difference.

States:
- unsaturated control: `h0 = -75 cm`;
- near-saturated: `h0 = +0.1 cm`;
- ponded/saturated: `h0 = +2 cm`;
- stronger saturated storage signal: `h0 = +10 cm`.

For each state use:
- one equilibrium/no-perturbation control;
- one bounded positive top-flux perturbation;
- one bounded negative top-flux perturbation.

The runner may reduce perturbation magnitude only if the preregistered case
cannot complete in any of the three regimes; any such change must be recorded
before accepting results. It may not tune perturbations separately by regime.

## Observations

For every case/regime record:
- completed/committed/status;
- accepted substeps;
- solver iterations;
- nonlinear iterations;
- internal retries;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- headcalc calls;
- interval mass residual;
- final pressure-head checksum;
- final water-content checksum.

For repeated same-origin timing record per regime:
- median ns/interval over at least 5 timing replicas;
- each replica after warmup;
- identical case order and call count;
- no arithmetic combination with historical PROFILE04 speedups.

## Hypotheses

H1. Unsaturated `h0=-75 cm` is a negative/control result: active ELAS should not
produce a systematic numerical-work change because the constitutive ELAS term is
inactive for `h<0`.

H2. Saturated cases may show different head response and nonlinear work because
storage capacity changes physically; exact physical identity across regimes is
not expected and is not an acceptance criterion.

H3. If GENERATED materially reduces retries/nonlinear/backtracking work relative
to OFF across the saturated bank without a material per-interval runtime
penalty, that is evidence for a follow-up timestep/solver interaction study.

H4. If FIXED_1E6 and GENERATED behave differently, the difference must be
reported rather than using `1e-6` as a proxy for the generated prior.

## Gates

A1. Generated parameter preparation succeeds through admitted application seams
and yields finite positive node-local Ss.

A2. OFF, FIXED_1E6 and GENERATED all complete the frozen bank or failures are
reported as results without hidden fallback.

A3. Every completed interval satisfies the existing hard mass gate.

A4. Unsaturated control constitutive/state setup is internally consistent for
all three regimes.

A5. Numerical-work counters are recorded for every case/regime.

A6. Repeated timing uses the same case and call count for all three regimes and
reports raw replica medians.

A7. O0/O2 classification and non-timing counters agree. Timing itself is
observation-only and need not be bit-identical.

A8. No `src/**` production change.

## Non-claims

ELASTIC46 does not:
- select a default Ss;
- calibrate ELAS;
- change timestep control;
- change convergence tolerances;
- change solver/globalization policy;
- claim generated ELAS improves accuracy;
- claim a portable speedup from CI timing.

## Decision rule

ELASTIC46 ends as a measured research result.

Only a clear repeated saturated-regime interaction between ELAS and numerical
work may justify a subsequent dedicated optimization/interaction workunit.
No production admission follows directly from this characterization.
