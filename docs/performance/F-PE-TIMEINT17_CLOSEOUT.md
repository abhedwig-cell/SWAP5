# F-PE-TIMEINT17 closeout — dynamic-top event semantics blocked by nonlinear globalization

Date: 2026-09-29

Final status:

`BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`

Canonical authority incorporated before closeout:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Final qualification/attribution authority includes:

- TIMEINT17A: same-route bank ineligible;
- TIMEINT17A2: route-margin bank still does not yield the required smooth same-route ladders;
- TIMEINT17B: endpoint solver dominates over route-event exclusion;
- TIMEINT17C: no hidden in-Newton route-switch explanation;
- TIMEINT17D: dynamic-top provider derivative and top-row Jacobian consistent;
- TIMEINT17E: mixed contraction/stagnation blocker;
- TIMEINT17F: dominant failures are usually interior, not top-boundary localized;
- TIMEINT17G: full 16-node residual/Jacobian is finite-difference consistent;
- TIMEINT17H: mixed merit signal, insufficient to authorize the preregistered scaled-merit H1 repair.

Final H authority:

- workflow run `36535199990`;
- globalization-merit-attribution job `109297652276`;
- conclusion: SUCCESS;
- classification: `TIMEINT17H_MIXED_MERIT_SIGNAL`.

## Executive conclusion

TIMEINT17 does **not** qualify dynamic-top event semantics.

The blocker occurs earlier.

The provider-consistent Thomas-Gladwell mechanism qualified by TIMEINT16 cannot yet be driven robustly through the frozen dynamic-top endpoint bank with the current HeadCalc nonlinear globalization policy.

The attribution chain excludes the main local-algebra explanations:

1. the issue is not merely that the original same-route bank crossed physical route events;
2. route-margin redesign does not produce the required qualification ladders;
3. endpoint solve failure is the dominant obstruction;
4. in-Newton route switching is not the hidden cause;
5. dynamic-top provider availability and surface derivative are not defective on the audited states;
6. the top-row residual/Jacobian is consistent;
7. the full tridiagonal residual/Jacobian is consistent across 768 audited failing iterates;
8. failed residual localization is mostly interior rather than concentrated at the dynamic top node.

The remaining research layer is nonlinear globalization / model-quality / state scaling.

## Why event localization is not opened

The parent TIMEINT17 contract required a positive same-route dynamic-top mechanism before known-time or endogenous event localization could be qualified.

That prerequisite was never satisfied.

Therefore TIMEINT17 does not authorize:

- FLUX -> HEAD event localization;
- HEAD -> FLUX release localization;
- runoff activation/deactivation localization;
- dynamic-top event splitting;
- event-time bisection;
- dynamic-boundary transaction admission.

These remain future work after endpoint robustness is restored under unchanged physical equations and mass semantics.

## H result

TIMEINT17H tested whether the current backtracking merit is sufficiently misaligned with the full convergence contract to justify the preregistered scaled-composite-merit line search.

Coverage:

- 768 audited failing Newton iterations;
- 2078 tested backtracking candidates;
- FLUX, HEAD and RUNOFF;
- B01, B12, O05 and O14;
- TG and matched KLAG;
- four dt levels.

Results:

- selected-factor mismatch fraction: `0.27604`;
- iterations with an available >=10% composite-merit improvement: `0.18229`.

The frozen H1 trigger required both to be >=0.25.

Therefore H0 classifies:

`TIMEINT17H_MIXED_MERIT_SIGNAL`

and H1 is not authorized.

The raw residual merit is imperfect, but simple replacement with the frozen composite merit is not sufficiently supported.

## Preserved positive authority

TIMEINT16 remains fully valid:

`QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`

On the smooth fixed-flux bank:

- head order about 1.998;
- moisture order about 1.998;
- physical interval mass at roundoff;
- provider-consistent current-step K staging;
- deterministic work ratio about 1.0 versus KLAG BE.

TIMEINT17 does not invalidate that mechanism.

It establishes that dynamic-top extension is currently blocked by nonlinear endpoint globalization before event semantics can be meaningfully qualified.

## Preserved negative authority

Do not revisit the following inside TIMEINT17:

- manual same-route bank tuning;
- global MAXIT increase;
- global tolerance relaxation;
- more backtracking iterations as an unqualified fix;
- top-row Jacobian repair;
- interior Jacobian repair;
- simple H1 composite-merit replacement;
- event-localization work before endpoint robustness is solved.

## Next bounded work

Open a separate work unit:

`F-PE-NLGLOB01 — Richards nonlinear model-quality and trust-region attribution`

Purpose:

determine whether endpoint failures arise because Newton's local linear model loses predictive quality outside the convergence basin, and whether scaling or trust-region diagnostics identify a principled globalization successor.

The first phase must be observational only.

It should preserve:

- the same residual;
- the same analytic Jacobian;
- the same A2 fixtures;
- the same K staging;
- the same physical mass contract;
- the same convergence thresholds;
- the same transaction semantics.

Initial diagnostics should compare, for each failing Newton iterate and tested step:

1. predicted residual reduction from the linear model;
2. actual residual reduction;
3. trust-region style agreement ratio;
4. raw head-step norm;
5. scaled head-step norm using physically/numerically defensible state scales;
6. dominant convergence-contract component;
7. route and residual localization.

No trust-region radius, Levenberg parameter, scaling constant or variable transform is to be selected until those diagnostics are preregistered.

## Relation to TIMEINT18

The TIMEINT16 closeout originally placed variable-step TG/LTE after event semantics.

That ordering remains correct.

Do not open TIMEINT18 variable-step/AUTO control while dynamic-top endpoint robustness remains unresolved.

The research sequence is now:

1. NLGLOB attribution and, if justified, bounded globalization repair;
2. return to TIMEINT17 same-route and event semantics;
3. only after positive TIMEINT17, open TIMEINT18 variable-step TG/LTE;
4. production-shaped integration remains later.

## Production boundary

No production `src/**` change is admitted by TIMEINT17.

No numerical default changes.

No mass-gate changes.

No dynamic-top event semantics are qualified.

No adaptive timestep work is admitted.

`LEGACY_NUMERICS` remains production default.
