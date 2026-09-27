# F-PE-PROFILE07 — post-TEMPORAL08 production performance rebaseline

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent authority:
`F-PE-TEMPORAL08 / PR #655`

Parent head at branch creation:
`7c363f777794d5d1f99fe430ec3507ec7c3d8bb6`

Branch:
`work/f-pe-profile07-post-temporal-rebaseline`

## Purpose

Re-establish the performance hotspot map after production admission of the frozen history-aware temporal budget

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`.

The previous PROFILE04 map predates this policy. PROFILE07 therefore treats historical hotspot percentages as hypotheses only and remeasures the current fastest production-shaped stack before opening another optimization workunit.

## Hard boundary

PROFILE07 is observation-only.

No `src/**` modification is allowed.

No new solver tolerance, hydraulic approximation, lookup representation, predictor, surrogate, batching policy or parallel execution policy may be admitted here.

If a new optimization target is identified, it must move to a separately preregistered follow-up.

## Questions

PROFILE07 must answer:

1. Where does repeated runtime now go after TEMPORAL08?
2. How much retry/candidate work has actually disappeared on the selected c=0.65 route?
3. Does the Reference/Richards/transaction route still dominate application runtime?
4. Is constitutive hydraulic evaluation still a material remaining kernel target?
5. Does directional/tangent work remain a dominant increment on the coupled route?
6. Is there enough measured evidence to prioritize one of:
   - reduced Richards solve effort;
   - hydraulic lookup/table representation;
   - stronger accepted-history prediction/reuse;
   - or, if single-column work is already sufficiently reduced, large-N batching/parallelism?

## Measurement rule

Do not construct a total speedup by adding percentages from different historical baselines.

Same-head paired measurements are authority.

Use replicated medians for timing claims. Isolated CI outliers are localization evidence only.

## P0 measurement set

P0 reuses existing qualified harnesses on the PROFILE07 head:

- PROFILE04 repeated application/backend decomposition;
- PROFILE04 constitutive and tridiagonal microkernel localization;
- PROFILE04 bottom-head directional timing;
- TEMPORAL06 repeated same-origin c=0.50 versus selected c=0.65 sequence;
- TEMPORAL08 production bootstrap/live preservation as a semantic guard.

At minimum preserve N=1,000 and N=10,000 application timing. Where existing harnesses expose N=1, include it, but do not invent extrapolated N=1 timings from large-N runs.

## Counters to retain

Where available record alongside wall time:

- solver calls;
- accepted internal solves/substeps;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- constitutive evaluations;
- headcalc calls;
- retries;
- solver rejections;
- temporal rejections;
- tangent fresh evaluations;
- tangent cache reuse;
- coupling iterations;
- mass/residual preservation.

## Decision gates

### SOLVE follow-up

Open a Richards solve-effort follow-up only if current measurements show repeated runtime remains dominated by accepted/retried Richards work and there is a measurable population with avoidable nonlinear or repeated solve effort.

### HYDRAULIC-TABLE follow-up

Open a hydraulic-table follow-up only if constitutive evaluation remains a material kernel cost after TEMPORAL08 and the expected gain is not already captured by the admitted direct-retention path.

The follow-up must test both raw evaluation cost and solver behavior. A faster but less smooth representation that increases nonlinear effort is not a performance success.

### HISTORY follow-up

Open a history/predictor follow-up only if current accepted-state information can plausibly reduce solve count, retries or nonlinear effort without changing physical ownership or commit semantics.

### MULTI-PERF follow-up

Batching/parallelism belongs after the single-column hotspot map is re-established. It must remain a distinct scaling workunit so single-column algorithmic gains and multi-column execution gains are not conflated.

## Explicit non-targets

PROFILE07 does not reopen the rejected APPROX04 same-origin response surrogate.

PROFILE07 does not retune c=0.65.

PROFILE07 does not introduce a ROM into the inner transaction loop.

## Closure criterion

PROFILE07 closes when:

- the post-TEMPORAL08 hotspot ordering is measured;
- the temporal-policy effect is confirmed on the current head;
- remaining candidate work is separated from necessary accepted solve work as far as existing diagnostics permit;
- exactly one immediate optimization workunit is recommended, with other credible tracks recorded as deferred;
- no production behavior has changed.
