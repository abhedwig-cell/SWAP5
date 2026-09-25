# F-PE-ZERO-WASTE01 H04 — constitutive phase-demand observation

Date: 2026-09-25

Status: `INSTRUMENTED_PENDING_QUALIFICATION`

## Question

The common constitutive provider returns a full tuple on every evaluation:

- water content theta;
- conductivity K;
- capacity C;
- dK/dh.

On the admitted explicit-provider Reference route with `SWKIMPL=0`, those components are not demanded at the same phase.

H04 measures whether full tuple evaluation is broader than required, without changing the provider ABI or numerical solution.

## Current exact control-flow interpretation

### Initial evaluation

Before Newton iteration 1 the full tuple is evaluated.

Immediate demand:

- K is used to construct conductivity means and the initial residual;
- C is reused for the first Jacobian after H03;
- theta is not the primary reason for this evaluation on the current path;
- provider dK/dh is reserved output and is not consumed by the admitted `SWKIMPL=0` path.

### Candidate/backtracking evaluation

After a trial head update, the provider evaluates the full tuple again.

Immediate demand:

- theta is required for the candidate residual;
- K is required directly by the provider-backed free-drainage lower boundary, but is not generally needed for all `SWKIMPL=0` bottom modes;
- C is only consumed if the candidate does not converge and another Newton iteration begins;
- provider dK/dh is not consumed on the admitted `SWKIMPL=0` route.

Therefore a full candidate tuple that immediately converges contains at least a capacity calculation whose result is never consumed by a subsequent Jacobian.

This is an observation hypothesis, not yet an authorization to split the provider ABI.

## Added counters

The instrumentation records:

- `constitutive_initial_full_evaluations`;
- `constitutive_candidate_full_evaluations`;
- `constitutive_candidate_terminal_evaluations`;
- `constitutive_candidate_capacity_reuses`.

Definitions:

- candidate terminal = the candidate tuple associated with an iteration that reaches convergence;
- candidate capacity reuse = a candidate tuple survives into the next Newton iteration and its C value is consumed there.

No counter changes control flow.

## H03 expected observation

For the existing one-Newton-iteration equilibrium H03 workload:

- total full evaluations = 2;
- initial full evaluations = 1;
- candidate full evaluations = 1;
- terminal candidate evaluations = 1;
- candidate capacity reuses = 0.

If observed, this proves that the candidate C calculation is unused on this workload.

It does not by itself prove the same for difficult multi-iteration workloads.

## Gates

1. FKT22 O0/O2 physical/runtime gate remains PASS.
2. Existing pressure-head, water-content, mass and trajectory identity checks remain unchanged.
3. Counter identities above hold for H03.
4. No constitutive formula, provider output, solver tolerance or branch is changed.
5. Negative/multi-iteration observations are retained before any repair is proposed.

## Next decision

Only after phase-demand observations on at least:

- one-iteration H03;
- a multi-iteration hydraulic workload;
- a free-drainage workload;

may H04 propose a narrower evaluation interface or provider-specific fast path.

The preferred repair, if evidence supports it, should avoid global ABI churn. A capability-specific or optional narrow evaluation path is preferred over weakening the existing full-tuple contract.
