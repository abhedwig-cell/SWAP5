# F-PE-ELASTIC57B — controller work and bounded-retry characterization result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic57b-controller-work-characterization`

Qualified workflow postimage:
`1ca10271044098837d0a93746294c7e998be57af`

Canonical baseline:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Workflow run:
`36707407177`

Job:
`109860824691`

Conclusion:
SUCCESS.

## Question

Does the ELASTIC57 nonmonotonicity-robust refinement pattern remain correct,
finite and practically characterizable when it is compared against a
monotonicity-assuming controller and an explicitly bounded retry controller?

## Parent and amendment

ELASTIC57 had already qualified C-SAFE over all threshold regions induced by the
frozen conservative indicator bank.

ELASTIC57B added the missing comparison and work characterization requested by
the ELASTIC56 handoff.

The first ELASTIC57B qualification attempt failed before controller
qualification because the originally preregistered exact
same-profile + same-h0 + same-regime monotone control did not exist for every
violating sequence. In particular, profile 11060, h0=+2 cm, OFF,
delta=+0.035 cm/day had no eligible control under that exact rule.

The preregistration was amended before reuse of any controller result:

- preserve profile and h0 exactly;
- first prefer identical forcing with a monotone alternative regime, prioritizing
  GENERATED;
- otherwise use same regime with opposite-signed equal-magnitude forcing;
- otherwise use the closest eligible monotone same-profile + same-h0 sequence.

The successful qualification used only this amended frozen rule.

## Replay and control bank

Exact parent replay:

- eligible sequences: `170`;
- nonmonotone sequences: `15`;
- matched-control mappings: `15`;
- C-SAFE / C-BOUNDED decision mismatches: `0`;
- safeguarded chatter: `0`.

The matched control set collapses to fewer unique sequences where multiple
violations map to the same control. Aggregate control-budget tests total
`87`.

## Controllers

Three controller patterns were compared.

`C-NAIVE`
terminates with `NONMONOTONE_ABORT` when a refined available indicator
increases after a failed available point.

`C-SAFE`
observes the current point and refines without assuming monotonic improvement.

`C-BOUNDED`
uses the same acceptance logic as C-SAFE but allows only the frozen initial
attempt plus at most eight retries and never goes below the ninth frozen dt.

Across the frozen nine-step bank C-BOUNDED matched C-SAFE exactly.

## Main result

Across all eligible sequences and all threshold-free induced budget regions:

| controller | tests | accept | exhausted | nonmonotone abort | attempts | retries | nonlinear iterations | indicator solves | composite work units |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| C-NAIVE | 1248 | 1069 | 155 | 24 | 5471 | 4223 | 25514 | 4966 | 30480 |
| C-SAFE | 1248 | 1078 | 170 | 0 | 5596 | 4348 | 27109 | 5028 | 32137 |
| C-BOUNDED | 1248 | 1078 | 170 | 0 | 5596 | 4348 | 27109 | 5028 | 32137 |

The lower work count of C-NAIVE is not an efficiency advantage. It comes partly
from prematurely aborting valid refinement paths.

C-SAFE and C-BOUNDED perform identical work on this finite frozen ladder.

## Violating sequences

On the 15 ELASTIC56 nonmonotone sequences:

| controller | budget tests | accept | exhausted | abort | attempts | retries | nonlinear iterations | indicator solves | work units |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| C-NAIVE | 88 | 64 | 0 | 24 | 139 | 51 | 1505 | 112 | 1617 |
| C-SAFE | 88 | 73 | 15 | 0 | 264 | 176 | 3100 | 174 | 3274 |
| C-BOUNDED | 88 | 73 | 15 | 0 | 264 | 176 | 3100 | 174 | 3274 |

C-NAIVE aborts in `24 / 88` induced budget regions.

Those aborts are the direct controller-level consequence of assuming that a
single dt refinement must reduce the indicator.

C-SAFE and C-BOUNDED have no such failure-to-progress behavior. They either
accept a passing observation or exhaust the finite ladder.

No safeguarded route revisits a dt, so observed chatter is zero by construction
of the forward-only retry policy.

## Matched monotone controls

On the matched monotone controls:

- budget tests: `87`;
- accept: `75`;
- exhausted: `12`;
- abort: `0`;
- attempts: `397`;
- retries: `310`;
- nonlinear iterations: `1945`;
- indicator solves: `352`;
- composite work units: `2297`.

All three controllers are identical on this set.

This separates the extra work on violating sequences from a general controller
penalty on matched monotone behavior.

## Regime result

### GENERATED

Across all eligible GENERATED sequences:

- budget tests: `477`;
- accept: `413`;
- exhausted: `64`;
- attempts: `2174`;
- retries: `1697`;
- nonlinear iterations: `9577`;
- indicator solves: `1983`;
- composite work units: `11560`;
- nonmonotone aborts: `0`.

C-NAIVE, C-SAFE and C-BOUNDED are exactly identical on every aggregate work and
decision counter in GENERATED.

Therefore the generic nonmonotonicity guard is behaviorally inert over the
observed GENERATED zero-violation regime.

This does not prove that GENERATED is universally monotone outside the tested
bank.

### OFF

C-NAIVE records `12` nonmonotone aborts across `320` budget tests.
C-SAFE and C-BOUNDED record none.

### FIXED_1E6

C-NAIVE records another `12` nonmonotone aborts across `451` budget tests.
C-SAFE and C-BOUNDED record none.

The controller failure is therefore not purely an OFF-only phenomenon even
though ELASTIC56 transition counts were overwhelmingly OFF.

## Frozen conservative envelope

For every paired accepted C-SAFE and C-BOUNDED observation:

`H_INF <= alpha * Binf`

remained satisfied.

Aggregate paired accepted observations for the safeguarded controllers:

`793`.

Envelope failures:

`0`.

The frozen alpha remained exactly:

`0.17320259355765216`.

No refit or tolerance calibration occurred.

## Hard mass gate

The research fixture retained:

- compartment balance tolerance = `1e-12`;
- total balance tolerance = `1e-12`.

The qualification driver verified both parameter and request materialization of
those gates.

Controller availability still requires a converged full solve plus available
indicator. Neither C-SAFE nor C-BOUNDED can bypass solver convergence.

Therefore the existing hard solver/mass acceptance gate is preserved.

The fixture does not emit a standalone mass-residual scalar, so ELASTIC57B does
not claim a separately remeasured residual distribution.

## Work-measurement boundary

Measured directly:

- inspected attempts;
- retries;
- unavailable attempts;
- solver nonlinear iterations;
- tridiagonal indicator solves;
- a transparent composite work count defined as
  `nonlinear iterations + indicator solves`.

Not exposed by the current research diagnostics:

- exact HeadCalc call count.

ELASTIC57B therefore does not infer HeadCalc calls from nonlinear iterations.

End-to-end bank runtime is also not used as a controller speed result because
the expensive physical bank generation is shared across controller simulations.

These are measurement limitations for future production-efficiency work, not
correctness failures of C-SAFE/C-BOUNDED.

## Hypothesis outcome

Safe controller correctness under localized nonmonotonicity:
SUPPORTED.

Finite bounded termination with at most eight retries:
SUPPORTED over the frozen nine-step ladder.

C-SAFE versus C-BOUNDED semantic identity:
SUPPORTED, zero decision or committed-dt mismatches.

Monotonicity-assuming controller robustness:
FALSIFIED, 24 nonmonotone aborts over the violating-sequence budget regions.

Frozen global conservative envelope:
PRESERVED, zero failures on 793 paired safeguarded acceptances.

Hard solver/mass acceptance:
PRESERVED.

Generic guard overhead in GENERATED:
OBSERVED ZERO at the controller-decision/work-counter level in this bank.

Exact HeadCalc-call characterization:
NOT ESTABLISHED because the current research diagnostics do not expose that
counter.

## Decision

Classification:

`QUALIFIED_BOUNDED_NONMONOTONICITY_ROBUST_CONTROLLER_WITH_GENERATED_GUARD_INERTNESS`.

The ELASTIC56 nonmonotonicity caveat is closed at research-controller level:

- a controller must not assume one-step monotonic improvement;
- a simple forward-only guarded refinement is sufficient over the tested bank;
- an explicit eight-retry bound terminates and reproduces C-SAFE exactly;
- the guard is behaviorally inert in GENERATED over the observed bank;
- no production physics, ELAS parameter, mass gate, alpha or temporal tolerance
  was changed.

No production admission is authorized.

The remaining production blockers are independent of this localized
nonmonotonicity question:

1. no independently qualified physical temporal acceptance budget is admitted;
2. the mode-7 indicator remains research-only;
3. exact HeadCalc-call and end-to-end controller runtime instrumentation remain
   unavailable in this research fixture;
4. production transaction-policy integration has not been qualified.

A next work unit should address the temporal budget independently. It should not
reopen ELASTIC56/57B controller monotonicity unless new evidence falls outside
this qualified dependency surface.
