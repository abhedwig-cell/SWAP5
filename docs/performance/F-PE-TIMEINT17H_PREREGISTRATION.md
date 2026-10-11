# F-PE-TIMEINT17H preregistration — nonlinear globalization merit and state-scaling attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17E: `TIMEINT17E_MIXED_CONTRACTION_BLOCKER`;
- TIMEINT17F: `TIMEINT17F_ROUTE_STRUCTURED_INTERIOR_DOMINANCE`;
- TIMEINT17G: `TIMEINT17G_FULL_JACOBIAN_CONSISTENT_GLOBALIZATION_BLOCKER`.

Canonical authority at preregistration:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Question

Is the current HeadCalc backtracking merit function misaligned with the complete nonlinear convergence contract on the endpoint failures reproduced by TIMEINT17?

This is an attribution workunit before any globalization repair.

## Current authority being tested

The existing backtracking policy accepts a trial factor when either:

`0.5 ||F_trial||_2^2 < 0.5 ||F_origin||_2^2`

or:

`max_i |F_trial_i| < CritDevBalCp`.

The final convergence decision is broader. It includes at least:

- compartment residual relative to `CritDevBalCp`;
- total balance relative to `CritDevBalTot`;
- absolute/relative pressure-head update relative to `CritDevh2Cp/CritDevh1Cp`;
- ponding-change criteria where applicable.

Therefore a locally correct Newton direction can be globalized by one merit function and judged by a different acceptance contract.

TIMEINT17G proves that the residual/Jacobian derivative itself is not the blocker on the audited failures.

## Literature context

Richards-equation literature documents strong sensitivity of Newton convergence to nonlinear relaxation, initial guesses, boundary conditions and convergence norms. Broader nonlinear-solver literature treats line search and trust-region methods as globalization mechanisms for exactly the case where local Newton information is valid but full steps are not globally reliable.

Relevant references:

- Paniconi and Putti (1994), Water Resources Research 30, comparison of Picard/Newton strategies for variably saturated flow;
- Farthing and Ogden (2017), Soil Science Society of America Journal, review of Richards numerical methods and globalization;
- Woodward (1998/2000), globalized Newton-Krylov methods for variably saturated flow;
- Huang, Mohanty and van Genuchten (1996), convergence criteria for variably saturated flow.

No literature result is treated as SWAP qualification. It motivates the bounded diagnostic only.

## Frozen bank

Use the exact TIMEINT17A2 endpoint-failure bank:

- materials: B01, B12, O05, O14;
- routes: FLUX, HEAD, RUNOFF;
- dt: 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- modes: TG and matched KLAG;
- MAXIT=8;
- MaxBackTr=8;
- unchanged tolerances;
- unchanged fixed-K staging;
- unchanged dynamic-top provider.

## H0 observational audit

At every Newton iteration of the terminal failing endpoint solve, preserve the existing solver behavior.

For each actually evaluated backtracking factor, record:

1. raw residual merit:
   `phi_raw = 0.5 ||F||_2^2`;
2. compartment normalized residual:
   `m_cp = max_i |F_i| / CritDevBalCp`;
3. total normalized balance:
   `m_tot = |sum_i F_i| / CritDevBalTot`;
4. normalized head increment for that factor:
   - if `|h_old_i| < 1 cm`: `|Delta h_i| / CritDevh2Cp`;
   - otherwise: `|Delta h_i / h_old_i| / CritDevh1Cp`;
   define `m_h` as the maximum over nodes;
5. if the route exposes an applicable ponding update criterion, normalized ponding-change merit `m_pond`; otherwise mark unavailable rather than zero;
6. composite convergence-contract merit:
   `M = max(m_cp, m_tot, m_h[, m_pond])`.

Also record:

- whether the current policy accepted the factor;
- which tested factor minimizes `phi_raw`;
- which tested factor minimizes `M`;
- dominant component of `M`;
- route and dominant residual location.

No trial choice is changed in H0.

## Frozen H0 classifications

### MERIT_MISALIGNMENT

`TIMEINT17H_MERIT_MISALIGNMENT`

if all coverage gates pass and both hold:

1. in >=25% of audited failing Newton iterations, the factor selected by the current policy is not the tested factor with minimum `M`;
2. in >=25% of audited failing iterations, some tested factor reduces `M` by at least 10% relative to the current selected factor.

### RAW_MERIT_ALIGNED

`TIMEINT17H_RAW_MERIT_ALIGNED_GLOBALIZATION_BLOCKER`

if <=10% of audited failing iterations meet either misalignment condition.

### MIXED

Otherwise:

`TIMEINT17H_MIXED_MERIT_SIGNAL`.

## Coverage gate

A conclusive H0 result requires:

- all FLUX, HEAD and RUNOFF route families;
- >=3 materials;
- >=3 dt levels;
- TG and KLAG represented;
- >=100 audited terminal-failure Newton iterations;
- >=300 tested backtracking candidates.

Otherwise:

`BLOCKED_TIMEINT17H_MERIT_COVERAGE`.

## H1 candidate, frozen but not executed unless H0 = MERIT_MISALIGNMENT

If H0 classifies `TIMEINT17H_MERIT_MISALIGNMENT`, H1 may test a research-only scaled sufficient-decrease line search.

The Newton direction and Jacobian remain unchanged.

Candidate factor sequence remains the existing:

`1, 1/3, 1/9, ...`

The candidate acceptance merit is the frozen composite `M`, not raw `phi_raw`.

A factor is eligible only if:

- all state/provider quantities are finite;
- route remains the same static route for the A2 fixture;
- `M_trial < M_origin`.

Among the existing factor sequence, accept the first eligible factor satisfying decrease.

No new factor interpolation is introduced.

No Wolfe/Armijo constant is tuned in H1. A stricter sufficient-decrease coefficient would require a separately preregistered successor.

## H1 success gates

H1 is a positive research signal only if, relative to the identical H0 bank:

1. endpoint-solve completion count strictly improves for both TG and KLAG or improves for one without regression in the other;
2. no physical/convergence tolerance is relaxed;
3. no mass gate is weakened;
4. no route transition is hidden;
5. successful endpoint candidates satisfy the unchanged convergence contract;
6. no nonfinite state;
7. median nonlinear work among completed endpoints does not exceed 1.50x the current policy.

Positive classification:

`TIMEINT17H_SCALED_MERIT_GLOBALIZATION_SIGNAL`.

If H0 shows misalignment but H1 does not improve completion:

`TIMEINT17H_MERIT_MISALIGNMENT_NOT_SUFFICIENT`.

## Stop rules

TIMEINT17H does not:

- increase MAXIT;
- increase MaxBackTr;
- relax balance/head/pond tolerances;
- change dt;
- change residual equations;
- change the Jacobian;
- change K staging;
- change route/event semantics;
- introduce trust-region radii;
- introduce Levenberg damping;
- change production `src/**`.

Trust-region or variable-transformation research is permitted only after H closes.

## Architecture invariants affected

- invariant 7, transactional timesteps: observational trials remain disposable;
- invariant 13, absolute mass conservation: unchanged;
- invariant 23, physical options versus solver policy: H changes only research numerical policy;
- invariant 25, reference mode remains available: unchanged;
- invariant 26, diagnostics: strengthened.

## Production boundary

Research/test-only.

`LEGACY_NUMERICS` remains production default.
