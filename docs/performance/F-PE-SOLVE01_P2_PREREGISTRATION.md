# F-PE-SOLVE01 P2 preregistration — production-shaped difficult coupled scale

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH`

Parent:
`F-PE-SOLVE01 P1`

## Trigger

P1 established that E4 and EH preserve the exact accepted endpoint and publication semantics under a live MODFLOW6 prepared-solve corrector.

However, the existing F-GC44 live case converges in only two exact iterations. In that short-loop regime E4/EH are about 25% slower because one additional external iteration plus exact validation/recovery overhead cannot be amortized.

P0B showed the opposite regime on difficult repeated correctors:

- E4: 62.5% fewer full Richards solves and about 56.45% median speedup;
- EH: 50% fewer solves and about 42.70% median speedup;
- EF: 75% fewer solves and about 70.15% median speedup.

P2 must determine which regime dominates in a production-shaped coupled workload.

## Primary question

Does E4 produce a net end-to-end speedup when live MODFLOW coupling contains enough repeated difficult corrector work and enough SWAP columns for discarded-trial solve elimination to matter?

## Comparators

Primary:

- E0 exact-every-trial;
- E4 bounded cadence.

Secondary:

- EF upper bound for headroom only.

EH is not a mandatory P2 arm. Reopen it only if E4 shows a robustness problem not present in P1.

## Workload requirements

P2 must use a live MODFLOW6 prepared-solve path and real SWAP participants.

The workload must contain:

- multiple SWAP columns, not one isolated participant;
- a mixture of difficult material/regime cases from the PROFILE06 matrix;
- repeated coupled intervals;
- enough external corrector work that E0 executes materially more than two SWAP trials per difficult interval;
- exact final SWAP validation before every commit;
- normal MODFLOW -> SWAP -> ledger publication ordering.

A workload that trivially converges in two iterations everywhere is not sufficient P2 authority.

## Scale levels

Measure at minimum:

- N = 1 difficult column, as control;
- N = 100;
- N = 1,000.

Use N = 10,000 only if the lower levels show stable scaling and CI/runtime cost remains practical.

The same physical case composition and forcing sequence must be used across E0 and E4.

## Frozen E4 policy

For each SWAP participant and captured origin:

- exact anchor response;
- up to three discarded intermediate responses from
  `q(h) = q_anchor + J_anchor (h-h_anchor)`;
- exact refresh after the third approximate response;
- exact validation at any apparent coupled convergence point;
- failed exact validation becomes a new exact anchor and coupling continues;
- only an exact validated candidate may commit.

Do not tune cadence after observing P2 results.

## Measurements

Per scale level and policy:

- total coupled wall-clock;
- wall-clock per interval;
- total MODFLOW outer/corrector iterations;
- total exact SWAP trials;
- total approximate SWAP responses;
- validation attempts;
- validation failures;
- refresh count;
- number of committed intervals;
- final heads and groundwater exchange;
- SWAP storage change;
- ledger exchange;
- mass/accounting diagnostics.

Report both aggregate totals and difficult-case tails.

## Primary performance metrics

`R_time = T_E4 / T_E0`

`S = T_E0 / T_E4`

`R_solve = N_exact_SWAPS_E4 / N_exact_SWAPS_E0`

Also report external-iteration amplification:

`A_iter = N_MODFLOW_E4 / N_MODFLOW_E0`.

## Advancement gate

E4 advances beyond SOLVE01 only if all hold on the largest completed production-shaped scale:

1. median or aggregate end-to-end speedup is at least 1.5x;
2. exact SWAP trial count is reduced by at least 40%;
3. MODFLOW iteration amplification is not greater than 20%;
4. exact final validation succeeds for every committed interval;
5. no approximate state is committed;
6. final exchange/storage behavior remains within the existing coupled physical authority;
7. mass and ledger accounting remain complete.

A speedup of 2x or more is a strong signal.

## Rejection conditions

Close the current E4 solve-elimination route if:

- end-to-end speedup is below 1.2x despite substantial solve reduction;
- extra MODFLOW iterations erase most solve savings;
- repeated exact-validation failures create material recovery work;
- difficult-case endpoint behavior becomes unstable or path-dependent;
- ownership or mass accounting differs from E0.

Do not respond to a failed P2 by tuning E4 cadence inside the same workunit.

Any new cadence or response representation requires a separate preregistered successor.

## Interpretation boundary

P2 is the first application-level performance authority for SOLVE01.

P0B is local repeated-corrector evidence.

P1 is live robustness evidence.

Only P2 may support a claim that discarded-trial solve elimination materially accelerates production-shaped MultiSWAP/MODFLOW execution.

No production admission occurs automatically from a P2 performance pass.
