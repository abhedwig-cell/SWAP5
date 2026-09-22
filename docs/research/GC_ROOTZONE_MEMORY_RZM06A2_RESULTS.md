# GC-RZM06A2 H2 state-pair construction result

Date: 2026-09-22  
Preregistration: `ae06b69b7b861b30934a0591958666d95726ff49`  
Implementation: `0e5ad1f711be44e7346384823ce62519782dc258`  
Qualified workflow: `35727006391`, job `106742998316`  
Production changes: none

## Decision

RZM06A2 does **not** produce an H2 endpoint pair. More specifically, it does not reach the endpoint-selection stage at all.

All 56 preregistered symmetric head-pulse trajectories fail in their first interval. The scientific disposition is therefore:

`CONSTRUCTION_INADMISSIBLE__H2_NOT_PROBED`.

This is distinct from the earlier RZM06A `NO_MATCH`. RZM06A had 23 accepted endpoints but no pair with enough M1 separation. RZM06A2 has zero accepted trajectories under its frozen long-window head-pulse construction.

## What was tested

Every trajectory used zero top forcing and the existing groundwater-head materializer. The intended state construction was:

- `H* + δH -> H* - δH -> H*`, or
- `H* - δH -> H* + δH -> H*`,

with frozen `δH` values from `1e-3` down to `1e-5 m` and pulse windows from `0.02` to `0.10 d`.

The H2 thresholds were unchanged:

- `|ΔW_profile| <= 1e-6`;
- `|ΔM1| >= 1e-4`.

No E_c response was exposed to pair selection and no H2 probe was opened.

## Failure signature

Representative failures, including the smallest head pulse at the shortest frozen pulse window, show the same pattern:

- C-ABI status: 7;
- kernel result status: 2;
- accepted substeps: 0;
- attempts: 9;
- retries: 8;
- temporal rejections: 9;
- solver rejections: 0;
- mass candidate not completed.

For example, `δH = 1e-5 m` with a `0.02 d` first pulse fails both upward and downward directions with exactly this retry-exhaustion pattern.

This points to the carrier's temporal-admissibility envelope, not to an accepted-state mass failure.

## Transactional negative control

Every failed first interval leaves the authoritative origin exactly unchanged:

- revision = 0;
- committed time = 0;
- ledger count = 0;
- ledger exchange = 0;
- committed profile observables unchanged.

The failure therefore strengthens the transaction-safety evidence even though it does not advance H2.

## Interpretation

The idea of using temporary H_c histories remains physically legitimate as a research state-construction mechanism, but the *frozen long-window realization* is not admissible under the existing serialized-reference temporal certificate and retry policy.

The next experiment must not change those numerical policies merely to force acceptance. Instead it should first map the admissible head-pulse scale at short windows, then build longer histories by repeating only already accepted micro-intervals.

The H2 water and M1 thresholds remain unchanged. RZM06A2 provides no evidence for or against the H2 physical hypothesis itself.
