# F-PE-ELASTIC57B — controller work and bounded-retry characterization preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent branch:
`research/f-pe-elastic57-controller-robustness`

Canonical authority at start:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Frozen global conservative scaling:
`alpha = 0.17320259355765216`.

## Why ELASTIC57B exists

ELASTIC57 qualified the threshold-free correctness pattern `observe -> test -> refine`
over all budget regions induced by the frozen bank.

That result did not yet satisfy the broader controller-characterization contract
requested after ELASTIC56. In particular it did not compare a monotonicity-assuming
controller against safeguarded and explicitly bounded retry policies, and it did
not aggregate solver work.

ELASTIC57B is therefore a bounded extension. It does not reopen or weaken the
qualified ELASTIC57 result.

## Frozen bank and eligibility

Replay the ELASTIC55/56 bank unchanged:

- profiles 11060, 10260, 8016, 3030;
- h0 = -75, -20, +2, +10 cm;
- delta = -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- the same nine-step dt-halving ladder;
- mode-7, swkimpl=0 research indicator;
- frozen alpha above;
- unchanged 1e-12 compartment and total-balance solver acceptance tolerances.

Parent eligibility remains at least three full-converged,
indicator-available points.

The replay must reproduce exactly:

- 170 eligible sequences;
- 15 nonmonotone eligible sequences.

All 15 nonmonotone sequences are mandatory test cases.

## Matched monotone controls

For every nonmonotone sequence choose one matched monotone control.

The first qualification attempt showed that an exact same-profile + same-h0 +
same-regime monotone control does not exist for every violating sequence. This is
a bank-feasibility fact, not a controller result. The control rule is therefore
amended before controller qualification as follows:

1. same profile, h0 and delta, but a monotone alternative regime; preference
   order GENERATED, FIXED_1E6, OFF;
2. if unavailable, same profile, h0 and regime with opposite-signed delta of the
   same absolute magnitude;
3. if unavailable, same profile and h0, minimizing first regime mismatch, then
   absolute delta distance, then numeric delta ascending;
4. if no same-profile + same-h0 monotone sequence exists, qualification fails.

This preserves profile and physical initial state for every control and, where
possible, preserves forcing exactly while varying only the ELAS regime. It also
directly tests whether the generic guard is inert on the observed GENERATED
zero-violation route.

Duplicate controls are retained only once in aggregate counts but the mapping
from each violating sequence to its selected control is emitted.

No result-dependent manual selection is allowed.

## Threshold-free budgets

As in ELASTIC57, define for each available observation:

`E_i = alpha * Binf_i`.

For each sequence, test every distinct positive acceptance region induced by the
observed E values:

- one budget below the minimum;
- one geometric-mean budget between every adjacent pair of distinct E values;
- one budget above the maximum.

No physical temporal tolerance is fitted or implied.

## Controllers

### C-NAIVE

A monotonicity-assuming comparator.

Process available attempts from largest to smallest dt.
After an available failed attempt, if the next available refined attempt has
`E_next > E_previous * (1 + 1e-12)`, terminate the interval as
`NONMONOTONE_ABORT`.

Otherwise accept the first available point with `E <= budget`.
If the ladder ends first, return `EXHAUSTED`.

C-NAIVE is characterization only and cannot be an admission candidate.

### C-SAFE

The qualified ELASTIC57 rule:

- unavailable full solve or indicator: refine;
- available and E <= budget: accept;
- otherwise refine;
- if the ladder ends: EXHAUSTED.

It makes no monotonicity assumption.

### C-BOUNDED

The same acceptance rule as C-SAFE, with an explicit finite retry bound:

- initial attempt plus at most 8 retries;
- minimum dt is the ninth frozen ladder value;
- no attempts below the frozen minimum dt;
- after the bound is consumed without acceptance: EXHAUSTED.

Because the bank itself has nine attempts, C-BOUNDED is expected to preserve
C-SAFE decisions while proving finite termination. Any decision difference is a
falsification requiring attribution.

## Hard mass gate

Hard mass acceptance remains a separate, unchanged gate.

The underlying fixture sets both compartment and total-balance tolerances to
`1e-12`. ELASTIC57B may consider an attempt controller-available only when the
full solver reports `SW_SOLVE_CONVERGED` and the indicator is available.

The controller is forbidden to reinterpret, relax or bypass solver convergence
or mass tolerances.

The fixture does not currently emit a standalone mass-residual scalar. Therefore
ELASTIC57B can qualify preservation of the existing hard solver gate, but it may
not claim an independently remeasured mass-residual distribution.

## Work metrics

For every controller/budget execution record:

- decision: ACCEPT / EXHAUSTED / NONMONOTONE_ABORT;
- committed dt when accepted;
- attempts inspected;
- retry count;
- unavailable attempts;
- accumulated full-solve nonlinear iterations for inspected attempts;
- indicator solves for available inspected attempts;
- paired accepted endpoint status;
- frozen-envelope status.

Aggregate separately for:

- all eligible sequences;
- all 15 violating sequences;
- matched monotone controls;
- OFF, FIXED_1E6 and GENERATED.

Exact HeadCalc-call count is required if the existing diagnostics expose it
without production changes. If it is not exposed, this must be reported as a
measurement limitation rather than inferred from nonlinear iterations.

Runtime measurement is permitted only for semantically comparable controller
replay overhead. The expensive bank generation is shared and is not to be
misrepresented as controller-specific runtime.

## Gates

B1. Exact parent replay: 170 eligible and 15 nonmonotone sequences.

B2. Deterministic matched-control selection succeeds for every violating
sequence.

B3. C-SAFE never accepts unavailable or over-budget observations.

B4. C-BOUNDED terminates for every tested budget and exactly matches C-SAFE
accept/reject decisions and committed dt over the frozen nine-step ladder.

B5. No C-SAFE or C-BOUNDED accepted paired observation violates the frozen
global envelope.

B6. Hard solver/mass acceptance semantics are unchanged.

B7. C-NAIVE behavior on the 15 violating sequences is measured, not patched or
special-cased.

B8. Work counters are emitted for each controller and stratified set.

B9. GENERATED is evaluated separately to determine whether the generic guard is
behaviorally inert and low-overhead over the observed zero-violation regime.

B10. Zero `src/**` changes.

## Falsification

A safeguarded route is falsified if it:

- weakens hard solver/mass acceptance;
- accepts above the active conservative budget;
- violates the frozen global envelope on a paired accepted point;
- fails to terminate within the bounded ladder;
- chatters between already visited dt values;
- requires special recognition of the 15 known violating sequences;
- changes physical or ELAS parameters.

A production-efficiency claim is not authorized by this work unit.

## Decision scope

A green result may qualify a bounded research statement about controller
correctness, finite termination and observed work on this frozen bank.

It does not authorize:

- a production physical temporal tolerance;
- replacement of `fmr_serialized_temporal_identity`;
- production mode-7 indicator admission;
- source changes;
- ELAS default-on behavior;
- swkimpl=1;
- a production speed claim.


## Preregistration amendment record

The initial ELASTIC57B run failed before controller qualification because the
original exact same-profile + same-h0 + same-regime control rule had no eligible
monotone control for at least one violating sequence
(profile 11060, h0=+2 cm, OFF, delta=+0.035 cm/day).

No controller result from that failed run is used to select or tune the amended
rule. The hierarchy above is based only on control availability and the already
qualified ELASTIC56 regime attribution.
