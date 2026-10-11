# F-PE-TIMEINT17B result — endpoint failure versus route-event attribution

Date: 2026-09-29

Status:

`TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`

Secondary attribution:

`TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36530500976`;
- job: `109282889959`;
- conclusion: SUCCESS.

## Frozen census

TIMEINT17B reused the frozen A2 bank and numerical settings and replaced the generic `ELIGIBLE=0` outcome with explicit terminal causes.

TG census:

- runs: 48;
- complete same-route: 0;
- non-complete: 48;
- `ENDPOINT_SOLVE_FAILURE`: 48/48;
- converged route-event outcomes: 0/48;
- route-event fraction: 0.0;
- endpoint-solver fraction: 1.0.

The frozen primary classification is therefore:

`TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`.

## TG versus KLAG attribution

Of the 48 TG endpoint failures:

- 45 have the same endpoint-solve failure in KLAG;
- shared endpoint-failure fraction: 0.9375;
- TG-specific endpoint robustness signals: 0.

This satisfies the frozen secondary attribution:

`TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`.

The blocker is therefore not specific to the Thomas-Gladwell current-step predicted-K staging.

It lies in the shared dynamic-top endpoint solve path or in the nonsmooth boundary composition seen by that solve.

## Event consequence

No converged endpoint route-event evidence exists in this census:

- onset evidence: false;
- release/runoff evidence: false;
- event-span gate: false.

Therefore TIMEINT17 must not open physical event localization yet.

A failed endpoint solve cannot be re-labelled as a route event.

## Mass consequence

Accepted-state physical mass remains valid:

- accepted-mass gate: PASS;
- failed/rejected endpoint trials publish no physical mass;
- no history mass or storage-derived flux correction is introduced.

## Interpretation

TIMEINT17A/A2 originally appeared route-unstable because all paths were exposed as generic ineligible trajectories.

TIMEINT17B resolves that ambiguity.

The immediate failure is endpoint nonlinear convergence before a converged new route can be classified.

Because the failure is shared by TG and KLAG in 93.75% of TG endpoint failures, increasing or retuning the TG method itself is not justified.

The next attribution target is the dynamic-top route path **inside** endpoint Newton/backtracking evaluations.

Specifically, determine whether the boundary provider:

1. remains on one physical route throughout a failed nonlinear solve;
2. switches route one or more times inside Newton/backtracking;
3. produces discontinuous residual/Jacobian behavior at those internal switches.

That attribution can distinguish a true shared solver defect from a boundary-event surface encountered inside the nonlinear trial.

## Required successor

Open:

`F-PE-TIMEINT17C — in-Newton dynamic-top route-path attribution`.

TIMEINT17C is diagnostic only.

No MAXIT or tolerance changes are permitted.

## Production boundary

No production `src/**` change.

No mass-gate change.

No event localization.

No adaptive timestep work.

`LEGACY_NUMERICS` remains production default.
