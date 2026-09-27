# F-PE-SOLVE01 P2B result — live difficult-regime corrector demand

Date: 2026-09-27

Status: `PASS_NEGATIVE_CLOSE_TRIGGER`

PR:
`#654 — F-PE-SOLVE01: bounded discarded-trial Richards solve elimination`

Qualified live matrix:
12 frozen difficult regime/history groups, MODFLOW6 6.8.0.

## Demand result

E0 exact-trial demand classification:

- SHORT: 8 / 12 groups;
- MODERATE: 4 / 12 groups;
- REUSE-RICH: 0 / 12 groups.

The four MODERATE groups are:

- B01 wet, -10% history;
- B01 wet, +10% history;
- O05 wet, -10% history;
- O05 wet, +10% history.

Each of these requires four exact E0 corrector trials.

All remaining groups close in two exact E0 trials.

No tested live group requires five or more exact corrector trials.

## E4 live behavior

Across the 12-group matrix:

- E0 exact trials: `32`;
- E4 exact trials: `18`;
- exact-trial ratio: `0.5625`;
- exact-trial reduction: `43.75%`.

Despite this solve reduction:

- aggregate runtime ratio E4 / E0: `1.060966399`;
- aggregate E4 runtime change: `6.096640% slower`.

The cause is external iteration amplification and exact-validation overhead.

Representative behavior:

### SHORT groups

Most SHORT groups move from:

- E0: 2 iterations / 2 exact trials

to:

- E4: 2 iterations / 1 exact trial + 2 approximate responses + 1 exact validation.

These can show modest local runtime gains of roughly 10-15%.

O14 wet is less favorable:

- E0: 2 iterations;
- E4: 3 iterations;
- one failed validation/recovery;
- approximately 21-31% slower.

### MODERATE groups

B01 wet and O05 wet move from:

- E0: 4 iterations / 4 exact trials

to:

- E4: 6 iterations / 2 exact trials + 5 approximate responses + 1 exact validation.

Although E4 halves the exact SWAP trial count, the two additional coupled iterations make it slower:

- B01 wet: approximately 18-20% slower;
- O05 wet: approximately 14-15% slower.

## Correctness authority

For every E4 group:

- the accepted endpoint remains within the frozen F-GC44 head authority;
- final q remains within the frozen physical authority;
- final physical residual passes;
- the committed ledger is consistent with the exact validated final q;
- one SWAP revision is committed;
- one ledger exchange is committed;
- no approximate candidate state is published.

Thus the negative performance result is not caused by an ownership or correctness failure.

## Preregistered advancement decision

P2B required either:

1. at least 25% of groups to be REUSE-RICH; or
2. positive aggregate E4 live wall-clock gain.

Observed:

- REUSE-RICH: `0 / 12`;
- aggregate E4 speedup: `-6.096640%`.

Neither advancement condition passes.

Decision:

`CLOSE_SOLVE_ELIMINATION_INSUFFICIENT_LIVE_DEMAND`

Do not construct a larger favorable live workload to rescue E4.

## Interpretation

SOLVE01 establishes two results that must be kept separate.

First, the conditional mechanism is real and large:

- scripted difficult corrector sequences: about 56% E4 speedup;
- N:1 real-participant scaling through N=1,000: about 62% E4 speedup;
- N=1,000 SWAP-side factor: about 2.65x.

Second, the tested live coupled application does not request enough repeated correctors:

- no REUSE-RICH groups;
- most intervals close in two exact trials;
- the harder four-trial groups incur additional E4 MODFLOW iterations;
- aggregate live performance is worse, not better.

Therefore discarded-trial solve elimination is a conditional optimization opportunity, not a justified default MultiSWAP/MODFLOW acceleration on the current live authority.
