# F-PE-ELASTIC58 — external temporal head-budget transferability preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent postimage:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority at start:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Question

Can an independently qualified temporal head-error scale from the TEMPORAL05
line be transferred, without refit, to the conservative mode-7 defect-indicator
envelope and C-SAFE controller pattern?

This workunit is a transferability/falsification test. It does not create a new
production F-CI14 numeric profile.

## Independent external authority

TEMPORAL05 blind holdout reports:

- selected history coefficient: `c=0.65`;
- blind-holdout max terminal absolute head error versus refined oracle:
  `6.5653e-3 cm`;
- calibration max terminal absolute head error:
  `3.369e-3 cm`;
- hard mass closure retained.

ELASTIC58 freezes these two independent benchmark levels before replay:

- `B_LOOSE = 0.0065653 cm`;
- `B_STRICT = 0.003369 cm`.

They are not fitted from ELASTIC55-57 data.

The TEMPORAL05 history formula itself is not transferred because the isolated
ELASTIC55/57 bank does not own a preceding accepted-state
`||h_dot_previous||` history. Only the independently observed physical
head-error levels are tested.

## Frozen replay

Reuse the complete ELASTIC55-57 four-profile bank exactly:
- profiles 11060, 10260, 8016, 3030;
- same profile retention/geometric/generated-Ss materialization;
- same states, forcing, regimes and nine-step dt ladder;
- same mode-7 research indicator;
- same frozen global scale
  `alpha = 0.17320259355765216`;
- same C-SAFE refinement logic.

For each full-converged indicator point define:

`E_bound = alpha * Binf`.

For each external benchmark independently, C-SAFE accepts the first available
dt satisfying:

`E_bound <= B_external`.

If no available point satisfies the benchmark, return EXHAUSTED.

## Primary tests

For every accepted point with a paired full-versus-two-half endpoint:

1. `H_INF <= E_bound` must hold under the frozen ELASTIC54/55 envelope.
2. `H_INF <= B_external` must therefore hold.
3. Record the acceptance dt and regime.
4. No unavailable point may be accepted.

## Transferability characterization

For each external benchmark report:
- total sequences;
- accepted sequences;
- exhausted sequences;
- paired accepted sequences;
- acceptance fraction;
- median accepted retry index;
- distribution by OFF/FIXED_1E6/GENERATED;
- all 15 ELASTIC56 nonmonotone sequences separately.

A benchmark is classified:

- `SAFE_AND_PRACTICAL_IN_BANK` if paired safety holds and at least 75% of
  sequences accept;
- `SAFE_BUT_OVERCONSERVATIVE_IN_BANK` if paired safety holds but fewer than
  75% accept;
- `FALSIFIED` if any paired accepted point exceeds the external head benchmark
  or the frozen alpha envelope.

The 75% practicality threshold is a research classification threshold only, not
a production temporal tolerance.

## Gates

A1. Parent profile selection and physical bank reproduce exactly.

A2. O0/O2 semantic identity.

A3. Frozen alpha is unchanged.

A4. External benchmark values are exactly the preregistered TEMPORAL05 values.

A5. C-SAFE accepts only available points satisfying the active external bound.

A6. Paired accepted points preserve both frozen alpha-envelope and external
head benchmark.

A7. All 15 parent nonmonotone sequences are included.

A8. Zero `src/**` production changes.

## Decision

A green result can qualify only transferability of an external physical
head-error scale into the current research controller/indicator composition.

It does not authorize:
- production F-CI14 numeric limits;
- mode-7 indicator production admission;
- production controller integration;
- a new default temporal tolerance.
