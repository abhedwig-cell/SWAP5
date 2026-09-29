# F-PE-TIMEINT14 handoff — conservative multistep Richards formulation

Date: 2026-09-29

Status: `READY_TO_START`

Repository:

`abhedwig-cell/SWAP5`

Current canonical authority:

`integration/f-ci-canonical@56a072f6484b8c8dd92e0c72bb2e71ab1d55ed94`

Active successor branch:

`work/f-pe-timeint14-conservative-bdf2`

At handoff, this branch is exactly identical to canonical and contains no TIMEINT14 work yet.

## Why this is now the main line

The original question was whether SWAP's legacy timestep regulation around DTMIN, DTMAX, iteration-count growth/shrink and multiple internal clamps should be redesigned rather than further tuned.

That question has now been answered.

TIMEARCH01 qualified a redesign of timestep architecture. Subsequent TIMEARCH work separated decision ownership, event scheduling, retry ownership, user bounds and automatic-controller experiments.

The first calibrated automatic heuristic controller did not generalize on blind validation. This moved the research question from controller heuristics to the temporal discretization itself.

The TIMEINT line has since reconstructed and tested modern alternatives to SWAP's current first-order semi-implicit Richards integration.

## Established TIMEARCH authority

### TIMEARCH01

Final status:

`QUALIFIED_TIMESTEP_ARCHITECTURE_REDESIGN`

The legacy architecture mixes independent concerns in one mutable dt:

- accepted-step numerical growth;
- nonlinear failure recovery;
- hard event alignment;
- process-specific clamps;
- day-boundary restart;
- user DTMIN/DTMAX bounds;
- transaction interval clipping;
- transaction retry;
- temporal acceptance/retry.

Qualified target separation:

- HardEventScheduler;
- StepProposalController;
- TrialExecutor;
- AcceptanceController;
- RetryController;
- DecisionTrace.

DTMIN/DTMAX are no longer treated as unquestioned central user controls. They may eventually become safety/advanced bounds or disappear from normal input.

### TIMEARCH17

Final status:

`CLOSED_GUARD_M5_BLIND_VALIDATION_FAILED`

The first calibrated AUTO_REFERENCE heuristic looked strong on calibration:

- 16/16 P-C1;
- about 33.6% median deterministic work reduction.

Blind validation failed:

- 17/20 P-C1;
- about 11.6% median work reduction;
- candidate-specific wet accuracy failures;
- transition-regime work regression.

Conclusion:

Do not continue threshold/state-machine rescue of legacy stepping. Move to temporal-discretization redesign.

## Established TIMEINT authority

### TIMEINT01 — reconstruct current temporal scheme

Final status:

`QUALIFIED_BDF2_SUCCESSOR`

Current SWKIMPL=0 Reference is a semi-implicit first-order one-step method:

- theta(h) implicit at endpoint;
- pressure gradient endpoint implicit;
- conductivity lagged from accepted origin;
- source/sink terms step-frozen;
- dynamic-top candidate-dependent/piecewise;
- Newton solves endpoint algebraic system.

Observed smooth temporal order is approximately one.

Variable-step BDF2 was selected as the primary modern successor candidate.

### TIMEINT02 — operator consistency

Final status:

`BLOCKED_IMPLICIT_OPERATOR_CONTRACT`

Changing only the storage derivative to BDF2 while retaining lagged conductivity does not yield second order.

Conclusion:

The complete operator treatment matters.

### TIMEINT03 — fully implicit BDF2

Final status:

`BLOCKED_BDF2_NONLINEAR_ROBUSTNESS`

Test-only SWKIMPL=1 Backward Euler is usable.

Fully implicit BDF2 is genuinely second order on smooth completed trajectories:

- refined orders about 2.05;
- work per step approximately equal to fully implicit BE.

One fine B01 trajectory failed. Raising MAXIT did not help and a linear extrapolation predictor made it worse.

### TIMEINT04 — nonlinear blocker attribution

Final status:

`CLOSED_BDF2_SMOOTH_FIXED_FLUX_MECHANISM_QUALIFIED`

The apparent nonlinear failure was actually a total-balance roundoff stall.

A representation-aware BDF2 balance floor restored:

- 4/4 smooth ladders;
- median refined order about 2.05;
- work per step about 0.99 of BE_KIMPL;
- endpoint changes only roundoff-scale.

Thus constant-step fully implicit BDF2 is a qualified second-order mechanism on the smooth fixed-flux envelope.

### TIMEINT05

Variable-step BDF2 was qualified as research authority with adjacent accepted-step ratio bounded approximately:

`0.5 <= r <= 2.0`

This remains an important design constraint.

### TIMEINT06-10 — cheap local error estimation

A sequence of increasingly strong error estimators was tested.

TIMEINT06:
- simple derivative-history estimator strongly correlated but was not conservatively calibrated.

TIMEINT07:
- analytical third-divided-difference LTE estimator had excellent ranking but one blind false-safe.

TIMEINT08:
- simplified one-linear-solve Richards response estimator retained strong ranking but still one false-safe.

TIMEINT09:
- exact final Newton Jacobian response remained highly predictive but produced five blind false-safe points at the strict 0.01 cm threshold.

TIMEINT10:
- embedded BE correction had zero blind false-safe but became far too conservative, only about 1.1% safe coverage.

Conclusion:

The smooth BDF2 mechanism is strong, but a cheap strict zero-false-safe local error estimator has not yet been found.

### TIMEINT11 — TR-BDF2 / ESDIRK feasibility

Final status:

`CLOSED_TRBDF2_DEFAULT_COST_TOO_HIGH`

A two-stage stiff embedded method was rejected as primary integrator because even optimistic work cost is about twice qualified BDF2.

Preferred smooth-regime modernization remains variable-step BDF2.

### TIMEINT12 — dynamic-top BDF2

Final status:

`BLOCKED_IMPLICIT_DYNAMIC_TOP_OPERATOR_ROBUSTNESS`

The fully implicit dynamic-top surface derivative was derived and qualified against finite differences.

However fully implicit BE on dynamic-top was not robust enough:

- only 6/12 MOIST/WET/POND cases complete;
- work-cost gates fail.

Therefore dynamic-top BDF2 was not opened.

Important: this is an operator/solver composition blocker, not an argument to return to legacy DTMIN/DTMAX tuning.

### TIMEINT13 — predicted/extrapolated conductivity BDF2

Final status:

`CLOSED_WITH_CONSERVATION_BLOCKER`

This is the current frontier.

Key findings:

1. BDF2 with history-predicted / extrapolated conductivity retains near-second-order behavior on smooth fixed-flux trajectories.
2. It avoids the strong fully implicit endpoint-conductivity coupling.
3. Dynamic-top nonlinear work is close to current KLAG behavior on completed cases.
4. Dynamic-top completion improved to 10/12 in the tested envelope.
5. The dominant blocker changed from nonlinear robustness to conservation semantics.

Smooth fixed-flux evidence:

- 4/4 ladders;
- median refined temporal order about 1.94;
- zero conductivity clamps;
- no material work-per-step penalty versus fully implicit BDF2.

Dynamic-top evidence:

- 10/12 cases complete;
- median work ratio versus KLAG about 1.01.

## Current blocker: multistep conservation versus interval mass contract

The tested BDF2 equation uses a multistep storage derivative such as:

`a0 theta_(n+1) + a1 theta_n + a2 theta_(n-1)`.

SWAP5 transaction/mass authority expects each accepted interval to satisfy the physical consecutive-state identity:

`storage_end - storage_start = integrated_in - integrated_out`

within qualified tolerance.

The tested BDF2 formulation systematically violates the ordinary accepted-interval ledger at roughly O(1e-3) to O(1e-2 cm) on completed multistep trajectories.

This must NOT be hidden by relaxing mass tolerances.

The issue is now a discretization/accounting design question.

## TIMEINT14 question

TIMEINT14 is the direct successor.

Primary question:

> Can a second-order multistep Richards formulation preserve SWAP5's physical accepted-interval conservation contract without sacrificing the qualified BDF2 order/performance mechanism?

TIMEINT14 should answer, in this order:

1. Can BDF2 be written in a conservative increment form that preserves physical interval storage change?
2. If not directly, can the multistep residual be separated from an exactly conservative physical flux ledger without changing the solved endpoint?
3. What temporal quadrature of boundary/source fluxes is required for second-order consistency?
4. Is conservation exact per accepted interval, only cumulatively over multiple intervals, or both?
5. Can transaction publication retain the current interval mass semantics unchanged?
6. Does the smooth near-second-order convergence survive the conservative formulation?
7. Does the predicted-conductivity advantage survive?
8. Only after the fixed-flux mechanism passes should dynamic-top be revisited.

## Non-negotiable constraints

- Do not relax water-balance tolerances to make BDF2 pass.
- Do not redefine mass conservation as a numerical residual.
- Keep physical interval ledger and temporal-discretization residual conceptually distinct.
- Preserve transaction commit/rollback semantics.
- Preserve BOFEK00 dynamic-top correctness.
- Preserve BALTOL02 authority unless a new, separately preregistered representation issue is demonstrated.
- No production source change before test-only mechanism qualification.
- No adaptive controller work until conservation is resolved.
- No new DTMIN/DTMAX tuning.
- Preregister every new formulation/gate before result exposure.
- Negative results are authority.

## Suggested TIMEINT14 phase structure

### P0 — mathematical/accounting reconstruction

Write the exact discrete balance equations for:

- current BE/KLAG;
- fully implicit BDF2;
- extrapolated-K BDF2.

Separate:

- solved algebraic temporal residual;
- physical storage increment over [t_n,t_(n+1)];
- integrated boundary/source flux over that same interval.

Determine analytically why ordinary endpoint flux integration does not match the multistep storage derivative.

### P1 — conservative formulations

Preregister a small set of candidate formulations before runs.

Candidate classes may include:

- conservative increment-form BDF2;
- conservative flux reconstruction/quadrature around an unchanged BDF2 endpoint;
- history correction carried as an explicitly nonphysical temporal term that cancels across intervals, only if the physical ledger remains exact and semantics are transparent.

Do not brute-force variants.

### P2 — smooth fixed-flux mechanism

Test first on the already qualified smooth fixed-flux bank.

Require:

- ledger passes;
- second-order convergence retained;
- no material work regression;
- variable-step ratio semantics remain valid where exercised.

### P3 — cumulative conservation

Run multi-interval trajectories and verify:

- per-interval physical ledger;
- cumulative ledger;
- no hidden history mass;
- no double counting at transaction commit.

### P4 — dynamic-top

Only if P0-P3 pass.

Reintroduce corrected dynamic-top with predicted conductivity and explicit event/regime restart semantics.

## Current production recommendation

No change.

`LEGACY_NUMERICS` remains production default.

The TIMEARCH redesign is qualified architecture, but modern BDF2 integration remains research authority until conservation and dynamic-top composition are solved.

## Exact restart point

Start directly on:

`work/f-pe-timeint14-conservative-bdf2`

At this handoff the branch equals:

`integration/f-ci-canonical@56a072f6484b8c8dd92e0c72bb2e71ab1d55ed94`

with no additional commits.

Fetch canonical and branch again before every write because parallel work is active.

