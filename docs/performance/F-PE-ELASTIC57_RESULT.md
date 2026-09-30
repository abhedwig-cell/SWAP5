# F-PE-ELASTIC57 — non-monotone-safe mode-7 controller replay result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic57-nonmonotone-controller`

Qualified postimage:
`8552b128f9e462bd5362baa9bd1a8c59569ff623`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36684028681`

Job:
`109785652490`

Conclusion:
SUCCESS.

## Question

Can a minimal retry controller remain safe when the qualified mode-7 research
indicator is locally non-monotone?

## Candidate

The research controller uses no monotonicity assumption.

For each interval it:
1. starts at the largest frozen dt;
2. skips unavailable/failed full solves;
3. computes `predicted_head_bound = alpha * Binf`, with frozen
   `alpha=0.17320259355765216`;
4. accepts the first point satisfying the research head budget;
5. otherwise continues to the next smaller dt;
6. never increases dt, extrapolates Binf or assumes that a halving must reduce
   the indicator;
7. returns exhausted if the frozen ladder contains no acceptable point.

No production source or transaction policy changed.

## Replay bank

The ELASTIC55/56 four-profile bank was replayed:
- profiles 11060, 10260, 8016, 3030;
- h0 = -75, -20, +2, +10 cm;
- delta = -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step halving ladder;
- O0/O2 semantic identity.

Research head-budget sensitivity values:
- 0.01 cm;
- 0.03 cm;
- 0.10 cm;
- 0.30 cm.

These are not production temporal limits.

## Primary safety result

Across all controller decisions:

- total decisions: `768`;
- accepted: `542`;
- safely exhausted: `226`;
- paired false accepts: `0`.

Every accepted point for which a direct full-versus-two-half H_INF was
available satisfied:

`H_INF <= head_budget`.

Therefore the threshold-only halving controller passed the independent
paired-state safety oracle over the complete replay bank.

## Budget behavior

### 0.01 cm

- accepted: `96`;
- exhausted: `96`;
- paired accepted observations: `90`;
- false accepts: `0`;
- deepest accepted retry index: `4`.

### 0.03 cm

- accepted: `128`;
- exhausted: `64`;
- paired accepted observations: `103`;
- false accepts: `0`;
- deepest accepted retry index: `7`.

### 0.10 cm

- accepted: `158`;
- exhausted: `34`;
- paired accepted observations: `131`;
- false accepts: `0`;
- deepest accepted retry index: `7`.

### 0.30 cm

- accepted: `160`;
- exhausted: `32`;
- paired accepted observations: `139`;
- false accepts: `0`;
- deepest accepted retry index: `7`.

Strict budgets therefore produce more fail-safe exhaustion, as expected.

## Retry-depth distribution for accepted intervals

Accepted controller decisions occurred at retry indices:

- 0: `294`;
- 1: `58`;
- 2: `28`;
- 3: `66`;
- 4: `27`;
- 5: `37`;
- 6: `27`;
- 7: `5`.

No acceptance requires a dt increase or a revisit of a previous retry index.

## Non-monotone sequences

The controller replay identifies 18 sequences with at least one local Binf
increase when all retained full-converged points are considered.

This includes the 15 ELASTIC56 parent-eligible sequences plus three two-point
non-monotone sequences that were outside the ELASTIC56 >=3-point attribution
eligibility rule.

Across the 72 controller decisions associated with these 18 sequences:

- accepts: `6`;
- exhausted: `66`.

The six accepts belong to three FIXED_1E6 sequences:
- profile 10260, h0=+2 cm, delta=+0.035;
- profile 10260, h0=+2 cm, delta=+0.05;
- profile 3030, h0=+2 cm, delta=+0.05.

Each accepts under two of the four research budgets and remains paired-safe.

The non-monotone OFF sequences all exhaust safely over this frozen ladder.

No GENERATED sequence in this replay exhibits the localized non-monotone
controller problem identified by ELASTIC56.

## Indicator increases encountered

Controller decisions encountered the following counts of Binf increases before
acceptance/exhaustion:

- 0 increases: `696` decisions;
- 1 increase: `24`;
- 2 increases: `8`;
- 3 increases: `24`;
- 5 increases: `4`;
- 6 increases: `12`.

Even sequences with repeated indicator increases remain safe because the
candidate never treats an increase as evidence for a larger timestep.

## Relation to ELASTIC56

ELASTIC56 established that local Binf nonmonotonicity is:
- concentrated in saturated states;
- positive-forcing dominated;
- overwhelmingly OFF;
- often contiguous and material rather than roundoff noise;
- compatible with the frozen global error envelope.

ELASTIC57 shows that this localized nonmonotonicity does not require a complex
controller response to remain safe.

A one-way halving controller with a threshold test:
- tolerates local Binf increases;
- does not oscillate;
- cannot be tricked into a dt increase;
- either reaches a safe accepted point or exhausts safely.

## Hypothesis assessment

H1, no paired false acceptance:
SUPPORTED, 0 false accepts.

H2, non-monotone sequences can be handled by the same threshold rule:
SUPPORTED for the tested bank; accepted cases use the same rule and OFF
problem cases exhaust safely.

H3, no oscillation because dt never increases within retry:
SUPPORTED by construction and replay.

H4, strict budgets may exhaust safely:
SUPPORTED.

## Decision

Classification:

`QUALIFIED_NONMONOTONE_SAFE_HALVING_CONTROLLER_RESEARCH_CANDIDATE`.

No production admission is authorized.

The next bounded workunit should evaluate end-to-end cost and transaction-level
integration of this candidate against the current Reference route, including:
- model-certificate Binf calculation cost;
- retries avoided versus exact-identity temporal acceptance;
- total nonlinear/tridiagonal work;
- accepted dt distribution;
- preservation of hard mass acceptance;
- fail-closed behavior when the certificate is unavailable.

A later production candidate must still bind an independently qualified head
budget. ELASTIC57 does not provide one.
