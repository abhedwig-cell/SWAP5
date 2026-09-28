# F-PE-TIMEINT01 current temporal discretization reconstruction

Date: 2026-09-28

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

## Discrete storage term

For every soil compartment the canonical residual contains:

`(theta(h^{n+1}) - theta^n) * dz / dt`

plus source/sink and vertical flux-divergence terms evaluated at the candidate endpoint.

This is the mixed-form backward Euler discretization of the storage term.

## Flux evaluation

The vertical Darcy fluxes are evaluated from the candidate pressure-head state at `t^{n+1}`.

For SWKIMPL=0:

- nodal conductivity is held at the accepted time-level value during Newton;
- candidate theta is updated from candidate h;
- flux gradients are candidate-state gradients.

For SWKIMPL=1:

- conductivity and dK/dh are updated implicitly with the candidate state.

TIMEINT01 remains initially bounded to the already admitted SWKIMPL=0 dynamic-top Reference route.

## Newton linearization

The Jacobian contains the storage derivative:

`C(h^{n+1}) * dz / dt`

plus flux Jacobian terms and boundary Jacobian terms.

For corrected dynamic-top head mode the top diagonal includes:

`K_surface / d_surface * (1 - dH_surface/dh_top)`.

Thus the current nonlinear solve is a Newton solve of a backward-Euler endpoint residual, not a higher-order temporal method.

## Formal temporal order

Away from nonsmooth boundary/process transitions, backward Euler is first-order accurate in time.

Its principal benefits are:

- strong damping;
- robustness for stiff diffusion-type systems;
- simple transactional endpoint semantics;
- one nonlinear solve per accepted interval.

Its limitation for SWAP5 is that it supplies no intrinsic estimate of local truncation error.

The current controller therefore infers timestep suitability indirectly from nonlinear iteration count, configured bounds and process/event rules.

## Dynamic-top complication

The dynamic-top boundary is piecewise:

- atmospheric/head;
- surface-flux;
- ponded-head;
- ponded-head with linear runoff.

A single interval can cross from one regime to another.

DYNERR01 demonstrated that an endpoint-linearized defect indicator can miss such path transitions completely.

Therefore any higher-order or embedded integrator must explicitly define what happens when stages/history span a dynamic-top regime transition.

A formal high-order formula does not by itself guarantee high-order behavior across a nonsmooth regime switch.

## Transaction/history implications

### Backward Euler

Committed history requirement:

- endpoint state only, plus existing process continuation history.

### BDF2

Requires at minimum:

- previous accepted endpoint state;
- previous accepted timestep;
- current accepted state.

With variable dt, coefficients depend on the timestep ratio.

After:

- startup;
- rejected history;
- hard discontinuity;
- process activation/deactivation;
- dynamic-top regime discontinuity,

the method must be able to restart with backward Euler.

### Derivative-based adaptive BE family

Requires accepted derivative/history information rather than a full second previous state.

SWAP5 already has accepted right-derivative history infrastructure in the temporal-certificate line, although current production scope is narrower than dynamic top.

That makes this family architecturally attractive.

## Candidate comparison

### Full step-doubling

Accuracy signal:
strong and direct.

Cost:
approximately three nonlinear interval solves when full and two-half are both computed.

Existing evidence:
robustness can improve, but most performance gain disappears.

Conclusion:
validation/oracle tool, not preferred normal production method.

### Variable-step BDF2

Accuracy:
second order in smooth regimes.

Normal-step solve count:
one nonlinear solve.

Advantages:
- potentially large accuracy gain per solve;
- uses existing endpoint residual structure;
- storage term generalization is conceptually direct.

Risks:
- extra accepted-state history;
- variable-step coefficient logic;
- dynamic-top regime transitions need restart semantics;
- Newton initial prediction matters;
- error estimation still needed.

### Embedded/adaptive BE-derived method

Accuracy/control:
can provide mathematically based local truncation-error control while staying close to backward Euler.

Advantages:
- closest migration path to current solver;
- can reuse current mass-conservative residual;
- literature specifically demonstrates this for mixed Richards equation;
- derivative/history infrastructure already exists in SWAP5;
- likely lower implementation burden than a multi-stage implicit RK method.

Risks:
- the published error estimator must be reconciled with dynamic-top nonsmooth transitions;
- current DYNERR01 endpoint defect is not equivalent to the Kavetski-style adaptive temporal approximation and must not be relabelled as such;
- exact discrete mass semantics of any correction/update must be proven.

### SDIRK / Rosenbrock-type pairs

Advantages:
- embedded error estimates can be mathematically clean;
- strong stiff-system theory.

Risks:
- multiple implicit stages;
- significantly larger code surface;
- stage-aware dynamic-top and process state;
- transaction and cumulative-flux bookkeeping become substantially more complex.

Conclusion:
not first prototype.

## TIMEINT01 design preference

The lowest-risk research order is:

1. prototype a backward-Euler-derived adaptive truncation-error estimator/corrector that reuses current residual/Jacobian and accepted derivative history;
2. independently prototype variable-step BDF2 on smooth fixed-boundary/dynamic-top-no-transition cases;
3. compare accuracy per nonlinear work;
4. only then decide whether a higher-order BDF route justifies migration complexity.

Do not start with SDIRK/Rosenbrock.

## Key architectural shift

A future AUTO_REFERENCE controller should ideally receive:

`local temporal error estimate -> desired dt`

rather than:

`Newton iterations/state threshold -> guessed dt`.

Solver effort remains a recovery/performance signal, not the primary temporal-accuracy proxy.
