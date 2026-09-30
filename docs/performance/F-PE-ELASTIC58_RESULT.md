# F-PE-ELASTIC58 — model-certificate transaction and cost characterization result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-transaction-cost`

Qualified postimage:
`737926b23e5849321bb402f07f32e399a7629f63`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36685477015`

Job:
`109790438797`

Conclusion:
SUCCESS.

## Purpose

ELASTIC58 tested two questions:

1. whether the existing `TX_TEMPORAL_MODEL_CERTIFICATE` transaction contract
   already implements the non-monotone-safe retry semantics required by
   ELASTIC57;
2. how much physical solver work a certificate route would require relative to
   the current exact-identity full-half Reference route over the same
   four-profile bank.

No production source or production policy was changed.

## Part A — transaction contract

A qualification-only scripted model exercised the actual
`execute_reference_interval` model-certificate route.

Qualified cases:

### Immediate certificate acceptance

A finite available normalized certificate <= 1:
- runs one full trial;
- runs no half trials;
- commits once;
- performs no rollback.

PASS.

### Temporal retry

A first certificate > 1 followed by <= 1:
- rejects the first attempt;
- rolls back;
- halves dt;
- accepts the second attempt.

PASS.

### Non-monotone certificate sequence

Scripted certificate sequence:

`2.0 -> 3.0 -> 0.5`

with requested dt sequence:

`0.8 -> 0.4 -> 0.2 day`.

The increase from 2.0 to 3.0 does not cause dt growth, oscillation or state
leakage. The route continues one-way halving and accepts the third attempt.

PASS.

### Certificate unavailable

An unavailable certificate:
- increments the unavailable-certificate counter;
- counts as temporal rejection;
- retries;
- exhausts safely when the retry budget is consumed;
- never commits;
- preserves the original committed state.

PASS.

### Hard mass gate

A mass-defective trial with an otherwise acceptable certificate:
- is rejected by mass first;
- never reaches temporal acceptance;
- never commits;
- preserves the committed state.

PASS.

### Retry exhaustion

Repeated certificate rejection:
- exhausts the configured retry budget;
- produces no commit;
- preserves the checkpoint state.

PASS.

Part-A classification:

`QUALIFIED_EXISTING_MODEL_CERTIFICATE_TRANSACTION_CONTRACT`.

No transaction-core change is required for the ELASTIC57 one-way-halving
semantics.

## Part B — physical work characterization

The ELASTIC55/57 four-profile bank was replayed with:

- profiles 11060, 10260, 8016, 3030;
- states -75, -20, +2, +10 cm;
- perturbations -0.05, -0.035, +0.035, +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- nine-step halving ladder;
- research mode-7 defect indicator;
- frozen global scaling
  `alpha=0.17320259355765216`.

The physical fixture was unchanged except for typed work-counter output.

The direct soil-water solver contract publishes:
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts.

It does not publish HeadCalc calls at this layer. That preregistered work
dimension was explicitly removed in
`F-PE-ELASTIC58_WORK_COUNTER_AMENDMENT.md`
rather than inferred.

The certificate route adds exactly one tridiagonal solve whenever a converged
full solve produces an available indicator.

The exact-identity comparison route uses the full + two-half trajectory and
continues refinement unless the endpoint states become exactly identical.

## Identity-route outcome

Across all 192 profile/state/forcing/regime sequences:

- exact-identity accepts: `0`;
- exact-identity exhaustions: `192`.

This is consistent with ELASTIC49-55: the current identity criterion remains
too strict to accept these finite full-versus-two-half differences.

## Certificate route by research head budget

### 0.01 cm

- certificate accepts: `96`;
- certificate exhaustions: `96`;
- certificate accepts where identity exhausts: `96`;
- paired accepted observations: `90`;
- unpaired accepts: `6`;
- paired false accepts: `0`.

Work:

- nonlinear: `9944 / 25367 = 0.3920` of identity work;
- Jacobian builds: same ratio `0.3920`;
- linear solves including certificate tridiagonals:
  `10613 / 25367 = 0.4184`;
- extra certificate tridiagonal solves: `669`;
- backtracking:
  `36737 / 80985 = 0.4536`.

### 0.03 cm

- certificate accepts: `128`;
- exhaustions: `64`;
- accepts where identity exhausts: `128`;
- paired accepts: `103`;
- unpaired accepts: `25`;
- paired false accepts: `0`.

Work ratios:

- nonlinear/Jacobian: `0.3328`;
- linear including certificate tridiagonal: `0.3552`;
- extra certificate tridiagonals: `569`;
- backtracking: `0.3818`.

### 0.10 cm

- certificate accepts: `158`;
- exhaustions: `34`;
- accepts where identity exhausts: `158`;
- paired accepts: `131`;
- unpaired accepts: `27`;
- paired false accepts: `0`.

Work ratios:

- nonlinear/Jacobian: `0.2621`;
- linear including certificate tridiagonal: `0.2800`;
- extra certificate tridiagonals: `456`;
- backtracking: `0.3053`.

### 0.30 cm

- certificate accepts: `160`;
- exhaustions: `32`;
- accepts where identity exhausts: `160`;
- paired accepts: `139`;
- unpaired accepts: `21`;
- paired false accepts: `0`.

Work ratios:

- nonlinear/Jacobian: `0.2312`;
- linear including certificate tridiagonal: `0.2454`;
- extra certificate tridiagonals: `360`;
- backtracking: `0.2885`.

## Cost interpretation

The certificate route requires one full nonlinear trajectory per attempted dt
instead of one full plus two half trajectories.

The one-extra-tridiagonal defect solve is small compared with the avoided
nonlinear trajectory work in this bank.

Across the research budget sweep the projected certificate route uses roughly:

- `23-39%` of identity nonlinear/Jacobian work;
- `25-42%` of identity linear work even after adding the defect solve;
- `29-45%` of identity backtracking work.

Equivalently, the observed work-count reduction is approximately:
- 61-77% for nonlinear/Jacobian work;
- 58-75% for linear work;
- 55-71% for backtracking.

These are work counts, not portable wall-clock speedups.

## Safety

For every certificate acceptance with a converged direct full-versus-two-half
comparison available:

`H_INF <= research head budget`.

Paired false accepts:
`0`.

Some certificate accepts occur where the two-half direct trajectory did not
fully converge, so no independent H_INF endpoint oracle exists for those
acceptances. They are reported separately as unpaired accepts and are not used
as direct validation of realized error.

Hard mass acceptance is not replaced by this error envelope.
Part A independently proves that the transaction contract rejects mass failure
before temporal commit.

## Hypothesis outcome

Existing model-certificate transaction semantics are suitable for one-way
non-monotone-safe halving:
SUPPORTED.

Certificate-unavailable behavior is fail-closed:
SUPPORTED.

Hard mass gate remains prior to certificate acceptance:
SUPPORTED.

Certificate route substantially reduces projected physical work relative to
exact-identity full-half:
SUPPORTED over the replay bank.

The extra one-tridiagonal indicator cost dominates the avoided nonlinear
trajectory work:
FALSIFIED. It is comparatively small in the work-count accounting.

Portable runtime speedup:
NOT ESTABLISHED. ELASTIC58 is not a wall-clock benchmark.

## Decision

Classification:

`QUALIFIED_MODEL_CERTIFICATE_TRANSACTION_AND_WORK_ADVANTAGE_RESEARCH_CANDIDATE`.

No production admission is authorized.

The next bounded workunit should perform a production-shaped runtime integration
of the research mode-7 certificate path, including:
- temporal-history bootstrap;
- actual `TX_TEMPORAL_MODEL_CERTIFICATE` serialized runtime execution;
- fail-closed certificate-unavailable behavior;
- hard mass preservation;
- matched wall-clock timing against the current exact-identity route;
- no production default change.

A production candidate still requires an independently qualified head budget.
