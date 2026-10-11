# F-PE-TIMEINT15 literature note — second-order conservative Richards time integration

Date: 2026-09-29

Status: `LITERATURE_RECONCILED_BEFORE_RESULTS`

Canonical authority at review:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

## Question

Which second-order temporal formulations are actually compatible with SWAP5's existing accepted-interval physical mass contract, and which formulations use a different but still legitimate notion of discrete conservation?

## Celia et al. (1990)

Celia, Bouloutas and Zarba established the mixed-form / modified-Picard route as a mass-conservative formulation for Richards' equation.

Relevant implication for SWAP5:

- use water content, rather than pressure-head capacity alone, as the discrete conserved storage quantity;
- do not infer mass conservation from pressure-head convergence alone.

Reference:

M.A. Celia, E.T. Bouloutas, R.L. Zarba (1990), Water Resources Research 26(7), 1483-1496, DOI 10.1029/WR026i007p01483.

## Tocci, Kelley and Miller (1997)

Their method-of-lines DAE treatment targets accuracy, explicit temporal-error control and good mass balance for Richards' equation.

The later 2026 DAE paper explicitly notes their use of trapezoidal temporal quadrature to estimate net boundary flux when higher-order multistep time integration is used.

Implication:

- DAE/BDF conservation and an exact consecutive-state interval flux ledger are distinct questions;
- temporal quadrature of boundary flux is not automatically identical to the BDF derivative equation.

Reference:

M.D. Tocci, C.T. Kelley, C.T. Miller (1997), Advances in Water Resources 20(1), 1-14, DOI 10.1016/S0309-1708(96)00008-5.

## Kavetski, Binning and Sloan (2001/2002)

Kavetski and co-authors developed mass-conservative second-order Richards time integration closely related to the implicit Thomas-Gladwell family. Their key design choice is to base the principal time approximation on moisture content while estimating temporal error in pressure head.

They report:

- second-order temporal accuracy;
- unconditional stability for the related Thomas-Gladwell approximation;
- adaptive error control;
- formulations designed for incorporation in backward-Euler Richards codes.

A related 2002 paper describes local extrapolation of backward Euler as equivalent to a second-order Thomas-Gladwell approximation at small marginal adaptive-control cost.

Implication for SWAP5:

Thomas-Gladwell/local-extrapolation is a serious one-step/finitely local fallback if trapezoidal integration proves oscillatory or too expensive. It must be derived against SWAP5's physical interval mass identity rather than imported as a pressure-only algorithm.

References:

D. Kavetski, P. Binning, S.W. Sloan (2001), Advances in Water Resources 24(6), 595-605, DOI 10.1016/S0309-1708(00)00076-2.

D. Kavetski, P. Binning, S.W. Sloan (2002), Water Resources Research 38(10), 1211, DOI 10.1029/2001WR000720.

## Keita, Beljadid and Bourgault (2021)

This study directly compares implicit and semi-implicit second-order Richards schemes, including BDF2 and extrapolation-based treatment of nonlinear terms.

Relevant result for SWAP5:

- second-order semi-implicit treatment of nonlinear hydraulic terms is a legitimate design family;
- extrapolation can reduce nonlinear cost;
- mixed saturation/pressure formulations can outperform more strongly coupled alternatives in their test setting.

This supports the TIMEINT13 observation that predicted conductivity is not intrinsically incompatible with second-order accuracy.

Reference:

S. Keita, A. Beljadid, Y. Bourgault (2021), Advances in Water Resources 148, 103841, DOI 10.1016/j.advwatres.2020.103841.

## Bootsma, Van der Ploeg and Weerts (2026)

This recent paper is especially relevant because it derives modified Picard as an exact Newton-Schur reduction of a DAE in which moisture content is retained as differential storage and pressure head is linked by a constitutive constraint.

It extends that construction to BDF2/BDF3 and correctly describes those schemes as discretely mass-conservative.

However, the paper also states that for BDF2/BDF3 the sum of instantaneous boundary flux contributions no longer directly balances consecutive physical storage change. Net boundary flux then requires additional temporal quadrature. Their higher-order benchmark therefore uses a prescribed constant top flux and no-flux bottom so total physical inflow is known independently.

This is fully consistent with TIMEINT14 rather than a contradiction:

- TIMEINT14 did not show that BDF2 loses water;
- it showed that BDF2's multistep discrete balance is not the same object as SWAP5's exact current accepted-interval consecutive-state ledger;
- the 2026 paper explicitly identifies the same boundary-flux reconstruction issue.

The paper therefore strengthens the distinction between:
1. discrete conservation of the temporal DAE/BDF residual; and
2. exact physical interval publication semantics.

Reference:

H.P. Bootsma, M.J. van der Ploeg, A.H. Weerts (2026), Advances in Water Resources 213, 105327, DOI 10.1016/j.advwatres.2026.105327.

## Decision for TIMEINT15

The literature supports three separate research families.

### Primary: one-step trapezoidal / Crank-Nicolson mixed balance

Reason:

- natural consecutive-state storage increment;
- current-interval flux quadrature;
- formal second order;
- directly testable against unchanged SWAP5 transaction mass semantics.

Risk:

- classical Crank-Nicolson can show bounded oscillations around abrupt forcing/boundary transitions.

### Preserved fallback: Thomas-Gladwell / local-extrapolation family

Reason:

- specifically developed for Richards;
- second order;
- moisture-based mass-conservative design;
- adaptive-error-control heritage;
- potentially better damping than classical trapezoidal integration.

This fallback is preregistered conceptually before TIMEINT15 results. It is not to be tuned post hoc inside the trapezoidal qualification.

### Separate architecture research: DAE/BDF with integrator-aware flux publication

The Bootsma et al. formulation is mathematically legitimate and worth retaining as a separate architecture line.

It is not a direct solution to the unchanged SWAP5 interval contract unless the boundary/source temporal quadrature is given an independently defensible physical current-interval meaning.

Therefore the existing branch `work/f-pe-timeint15-conservative-bdf2-current` is not discarded, but it must not label a recursive history-bearing flux integral as ordinary current-interval physical water without a separate contract decision.

## Frozen research order

1. qualify or reject one-step trapezoidal on the established smooth fixed-flux bank;
2. if the mechanism is positive, test predicted-K cost and then dynamic-top quadrature;
3. if trapezoidal is negative because of stability/robustness or cost, open a separately preregistered Thomas-Gladwell workunit;
4. keep DAE/BDF as a separate possible mass-contract redesign, not as a hidden reinterpretation of current transaction semantics.
