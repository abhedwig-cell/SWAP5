# F-PE-NLGLOB11A result — head-space endpoint coefficient predictor

Date: 2026-09-29

Status:

`CLOSED_TG_HEADSPACE_STAGE_PHYSICAL_ADMISSIBILITY_FAILED`

Canonical base:

`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Qualification authority:

- workflow run: `36552073887`;
- job: `109352378041`;
- conclusion: SUCCESS.

## Frozen candidate

The auxiliary endpoint coefficient stage was moved from moisture extrapolation to head space:

`h_dot_n = theta_dot_n / C(h_n)`

`h_tilde = h_n + h h_dot_n`.

The same constitutive provider evaluated `K_tilde` at `h_tilde`. The accepted TG update, S0 replay, mass contract, tolerances, MAXIT, backtracking and route physics were unchanged.

## Smooth TIMEINT16C bank

The smooth bank remains strongly second order:

- 4/4 ladders complete;
- median refined top-head order: `2.04787`;
- median refined top-theta order: `2.04787`;
- 4/4 individual head ladders >=1.5;
- median work ratio versus KLAG BE: `1.0`;
- physical/cumulative ledgers at roundoff;
- constitutive roundtrip and native endpoint balance within authority.

Thus endpoint-oriented head-space staging preserves the TIMEINT16C temporal-order mechanism.

## Dynamic-top replay bank

Nominal completed trajectories:

`79 / 96 = 0.82292`.

Physical ledgers for completed trajectories remain near roundoff:

- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`.

No legacy moisture-predictor domain exits remain and no head-space predictor failure is reported.

However, the frozen 96/96 execution gate fails:

- process failures: `7`;
- all seven missing trajectories are O05 / TG / HEAD or RUNOFF.

The corrected qualification harness therefore classifies the candidate:

`CLOSED_TG_HEADSPACE_STAGE_PHYSICAL_ADMISSIBILITY_FAILED`.

The earlier provisional “qualified” summary was invalid because the harness had omitted the preregistered `process_failures == 0` condition. That harness defect was corrected before this result was frozen.

## Interpretation

Head-space endpoint staging solves two important pieces simultaneously:

1. smooth second-order behavior is preserved;
2. the explicit moisture-predictor domain exit disappears.

But it does not make the full near-saturated TG trajectory physically admissible across the frozen dynamic-top bank.

The same O05 near-saturation family remains the hard failure population.

Therefore the remaining TG problem is not solely the coordinate used for the auxiliary coefficient predictor.

A successor must address the temporal construction of the accepted near-saturated TG state without clipping accepted moisture and without sacrificing endpoint-consistent coefficient staging.

## Preserved authority

- TIMEINT16C remains positive.
- NLGLOB10 Arm B remains valid.
- Canonical NLGLOB11 half-step negative authority remains valid.
- NLGLOB12 remains the separate authority for the 14 above-floor endpoint failures.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
