# F-PE-TEMPORAL04 P1 — bounded HIST_HALF qualification

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Candidate

`HIST_HALF = max(1e-5 cm, 0.5 * dt * ||h_dot_previous||_inf)`

Only this candidate advances from P0.

## Qualification envelope

The following bounds are fixed before P1:

- completion: 48/48 on the P0 difficult dynamic-history matrix;
- max terminal |dh| versus refined oracle <= 0.01 cm;
- max terminal |dtheta| <= 1e-5;
- max relative terminal bottom-flux difference <= 1%;
- max relative integrated bottom-exchange difference <= 0.5%;
- complete mass accounting;
- no nonfinite state, flux or budget.

These bounds are intentionally tighter than the broader practical-mode error tolerance used elsewhere in SWAP5 performance work.

## P1A — replicated oracle envelope

Repeat all 48 P0 physical points in three fresh processes.

Require deterministic completion and re-evaluate the full error envelope against the N=32 refined oracle.

## P1B — runtime and retry work

On all 48 points compare:

- HIST_HALF;
- FIXED_0P2 benchmark.

Use paired fresh-process batches and record:

- transaction status;
- wall-clock trial time;
- attempts/retries;
- temporal and solver rejection counts where exposed.

Interpret runtime only for points where both arms complete.

## Advancement gate

HIST_HALF may advance to production-shaped coupled replay only if:

- all P1A error bounds pass;
- completion remains 48/48;
- mass authority remains complete;
- runtime/retry behavior is no worse than FIXED_0P2 by a material margin across the matrix.

No production temporal-policy change is allowed.