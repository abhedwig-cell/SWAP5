# F-PE-BOFEK01 P1/P1R result — independent temporal oracle

Date: 2026-09-28

Status: `ORACLE_LIMITED_NO_ADVANCING_CANDIDATE`

Canonical authority:

`integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`

Current evidence:

- P1 Actions run `36413684951`, fixed-step temporal-oracle job SUCCESS;
- P1R Actions run `36413798107`, oracle-solvability job `108899998894`, SUCCESS;
- P1R evidence head `7a07a9d0e612e0b3fe26b541228735e4bb01ea1b`.

## P1 independent oracle

The preregistered oracle used identical fixed timesteps:

- coarse: `0.0005 d`;
- fine: `0.00025 d`.

A case was temporally resolved only when both fixed-step runs completed without retries/failure and their runoff, ponding, storage and top/mid/bottom pressure-head differences passed the frozen P1 bounds.

Result:

`1/16` screening cases produced a complete temporally resolved coarse/fine pair.

The resolved case was `O05/DRY`.

For that case, coarse versus fine oracle agreement was strong:

- top-head difference: about `3.54e-5 cm`;
- bottom-head difference: about `4.12e-9 cm`;
- runoff, ponding and storage differences: zero or round-off scale;
- water-ledger residuals: order `1e-15 cm`.

## Candidate comparison on the resolved case

No candidate passed the already frozen oracle accuracy gate on `O05/DRY`.

Top-head absolute difference versus the fine oracle:

- current adaptive Reference: about `0.002960 cm`;
- `DTMAX_X2`: about `0.004424 cm`;
- `DTMAX_X4`: about `0.003319 cm`;
- `DT0_HALFMAX`: about `0.002930 cm`;
- `DT0_MAX`: about `0.003329 cm`;
- `HEAD_X10`: about `0.002963 cm`;
- `HEAD_X100`: about `0.002979 cm`.

Frozen P1 top-head bound:

`0.001 cm`.

Therefore every shortlisted candidate, including the current adaptive Reference comparator, fails the only independently resolved screening case. No candidate can satisfy the P1 advancement rule.

## P1R oracle-solvability diagnostic

P1R tested whether the widespread fixed-step failures were simply caused by insufficient nonlinear iteration capacity.

The fixed temporal points and all convergence/accuracy settings remained unchanged.

Arms:

- O8: `MAXIT=8`;
- O20: `MAXIT=20`;
- O48: `MAXIT=48`.

Backtracking remained fixed at 8.

Result:

| arm | complete/resolved coarse+fine pairs |
| --- | ---: |
| O8 | 1/16 |
| O20 | 1/16 |
| O48 | 1/16 |

Increasing nonlinear iteration capacity therefore did not restore the independent oracle.

The failures remain fixed-dt nonconvergence at the prescribed minimum timestep in the other cases. P1R does not justify changing production MAXIT and does not authorize a finer post-hoc oracle.

## Decision

No strict candidate advances to interaction or holdout.

This conclusion does not depend on interpreting the 15 unresolved oracle cases as candidate failures. Every candidate already fails the one screening case for which the independent temporal oracle is demonstrably resolved.

The broad fixed-step oracle itself is nevertheless limited under current Reference authority. That limitation must be retained as part of the negative evidence.

Final consequence for BOFEK01/02:

`CLOSED_NO_POLICY_GAIN`

Qualifier:

`INDEPENDENT_ORACLE_BROADLY_LIMITED`

No production numerical-policy change is supported.
