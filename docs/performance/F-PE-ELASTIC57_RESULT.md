# F-PE-ELASTIC57 — threshold-free controller robustness result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic57-controller-robustness`

Qualified postimage:
`1fc6c380533cb5c1bf2b9dedc71660bc104499cf`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36678147962`

Job:
`109767545978`

Conclusion:
SUCCESS.

## Question

Can a timestep-refinement controller remain correct under the localized
mode-7 `Binf` nonmonotonicity qualified in ELASTIC56 without assuming that
every dt halving must reduce the indicator?

## Canonical policy boundary

F-CI14 still has no independently qualified numeric temporal limits.

ELASTIC57 therefore did not invent or calibrate a physical head-error budget.

Instead, for every observed sequence it tested all distinct accept/reject
regions induced by the conservative quantity

`E_i = alpha * Binf_i`

with frozen

`alpha = 0.17320259355765216`.

This makes the controller test threshold-free with respect to any new physical
tolerance.

## Candidate logic

C-SAFE processes the frozen dt ladder from largest to smallest dt.

For each candidate point:
1. unavailable full solve/indicator -> continue;
2. `E_i <= budget` -> accept that dt;
3. otherwise refine;
4. if no point passes -> EXHAUSTED.

C-SAFE never assumes `E_{i+1} <= E_i`.

## Bank

The complete ELASTIC55/56 four-profile bank was replayed:

- profile 11060;
- profile 10260;
- profile 8016;
- profile 3030;
- same materialization;
- same mode-7 research indicator;
- same states, forcing, regimes and nine-dt ladder.

Parent replay:
- eligible sequences: `170`;
- nonmonotone sequences: `15`.

Both counts reproduced exactly.

## Threshold-free controller result

Across all profile sequences and all induced positive budget regions:

- budget tests: `1265`;
- C-SAFE accepted: `1089`;
- C-SAFE returned EXHAUSTED: `176`;
- paired accepted observations: `795`.

No controller-oracle disagreement occurred.

Every acceptance was the first available dt on the frozen refinement path that
satisfied the conservative criterion.

No unavailable point was accepted.

No false acceptance above the active test budget occurred.

## Per-profile result

### profile 11060

- eligible sequences: 40;
- nonmonotone: 1;
- budget tests: 310;
- accepted: 266;
- exhausted: 44;
- paired accepted: 203.

### profile 10260

- eligible sequences: 43;
- nonmonotone: 5;
- budget tests: 328;
- accepted: 284;
- exhausted: 44;
- paired accepted: 210.

### profile 8016

- eligible sequences: 44;
- nonmonotone: 4;
- budget tests: 291;
- accepted: 247;
- exhausted: 44;
- paired accepted: 170.

### profile 3030

- eligible sequences: 43;
- nonmonotone: 5;
- budget tests: 336;
- accepted: 292;
- exhausted: 44;
- paired accepted: 212.

## Nonmonotonicity robustness

All 15 ELASTIC56 nonmonotone sequences were included.

C-SAFE remained correct because its logic depends only on the observed current
candidate value, not on an assumption that refinement must improve the next
indicator.

A local increase in `Binf` therefore causes only continued refinement or
EXHAUSTED. It cannot create a false acceptance.

This directly addresses the controller-design risk exposed by ELASTIC55/56.

## Conservative envelope preservation

For every accepted observation that also had a directly observed full-versus-
two-half endpoint error, the frozen ELASTIC54/55 envelope remained satisfied:

`H_INF <= alpha * Binf`.

No alpha refit occurred.

Hard mass acceptance remains outside this research controller and is not
weakened.

## Hypothesis outcome

Controller correctness without monotonicity assumption:
SUPPORTED over all 1265 induced budget tests.

Safe handling of unavailable points:
SUPPORTED.

Safe exhaustion when no observed dt passes:
SUPPORTED, 176 cases.

Frozen global envelope preservation:
SUPPORTED for all paired accepted observations.

Need for an assumed monotone Binf response:
FALSIFIED as a controller requirement.

## Interpretation

ELASTIC56 showed that Binf nonmonotonicity is real but localized.

ELASTIC57 shows that this does not require the indicator itself to be repaired
before a robust controller pattern can be defined.

The safe controller rule is simpler:

`observe -> test -> refine if needed`

rather than:

`predict monotonic improvement -> infer next acceptance`.

This preserves correctness even when a smaller dt temporarily produces a larger
indicator.

## Remaining production blocker

The controller logic is now qualified as a research pattern, but production
temporal control is still blocked by one central missing authority:

there is no independently qualified numeric physical temporal budget in
canonical F-CI14.

Without that budget, ELASTIC57 cannot define when the conservative indicator is
small enough for production acceptance.

## Decision

Classification:

`QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`.

No production admission is authorized.

The next bounded line should focus on independent calibration/qualification of
the physical temporal budget to be applied to the conservative mode-7 indicator
envelope, while preserving hard mass acceptance and the C-SAFE refinement
pattern.
