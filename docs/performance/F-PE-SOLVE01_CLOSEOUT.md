# F-PE-SOLVE01 closeout — discarded-trial Richards solve elimination

Date: 2026-09-27

Status: `CLOSED_CONDITIONAL_GAIN_NOT_LIVE_JUSTIFIED`

PR:
`#654 — F-PE-SOLVE01: bounded discarded-trial Richards solve elimination`

## Objective

Test whether full Richards solves used only for discarded same-origin coupling trials can be eliminated while retaining exact final SWAP authority.

The workunit deliberately separated:

- intermediate advisory coupling responses;
- exact commit-worthy SWAP state.

Approximate responses were never allowed to commit.

## Evidence chain

### EF upper bound

On the frozen difficult repeated-corrector matrix:

- 74.95% fewer full Richards solves;
- 70.69% median wall-clock gain;
- about 3.4x speedup;
- exact final q/state/ledger identity.

This established large conditional headroom.

### P0B bounded refresh frontier

E4:

- 62.5% solve reduction;
- 56.45% median wall-clock gain;
- about 2.30x speedup.

EH:

- 50.0% solve reduction;
- 42.70% median wall-clock gain.

E2 did not pass the advancement gate.

### P1 live MODFLOW robustness

On the short F-GC44 live case:

- E0: 2 iterations / 2 exact trials;
- E4: 3 iterations / 2 exact trials plus approximate steering and validation;
- E4 about 25.7% slower;
- exact accepted endpoint and publication semantics preserved.

This showed that the mechanism is robust but not automatically profitable in short live loops.

### P2A N:1 scale mechanics

Using the production-shaped shared-backend participant-registry/application-context path:

N=1:
- E4 speedup: 62.55%.

N=100:
- E4 speedup: 62.32%.

N=1,000:
- E4 speedup: 62.31%;
- exact tile-trial reduction: 60.61%;
- about 2.65x repeated-corrector speedup.

The SWAP-side benefit therefore survives MultiSWAP-scale participant counts.

### P2B live difficult-regime demand

Frozen 12-group live matrix:

- SHORT: 8;
- MODERATE: 4;
- REUSE-RICH: 0.

Totals:

- E0 exact trials: 32;
- E4 exact trials: 18;
- exact-trial reduction: 43.75%;
- aggregate E4 runtime ratio: 1.060966399;
- aggregate E4 runtime change: 6.10% slower.

Correctness and publication ownership remain valid.

## Final decision

The preregistered P2B advancement condition does not pass.

There are no REUSE-RICH live groups in the tested difficult matrix, and E4 does not provide positive aggregate live wall-clock gain.

Therefore:

`CLOSE_SOLVE_ELIMINATION_INSUFFICIENT_LIVE_DEMAND`

Do not proceed to a larger heterogeneous live scale benchmark for E4.

Do not admit E4 as a default or practical production policy.

## What SOLVE01 did establish

Discarded-trial solve elimination is technically real and potentially large.

If an external coupling algorithm produces long same-origin corrector sequences, E4 can remove most of the SWAP-side Richards work and scale that gain through at least N=1,000 participants.

That conditional opportunity should remain documented for future couplers or regimes with substantially higher corrector demand.

It is not currently justified by the tested live MODFLOW6 coupling behavior.

## Performance-roadmap implication

The main performance line should now leave solve-elimination and return to optimizations that reduce the cost of work that live coupling actually performs.

Priority order after SOLVE01:

1. reduce cost of the exact Richards trials that remain unavoidable in 2-4 iteration live loops;
2. retain already qualified retry/temporal improvements where independently admitted;
3. remove remaining redundant work on the exact live path;
4. only reopen discarded-trial approximation if a future production workload demonstrates materially higher corrector demand.

The SOLVE01 negative live result prevents further refinement of E4 cadence, response windows or surrogate shape without new external demand evidence.

## Production impact

None.

SOLVE01 changes no production source and admits no approximation policy.

The research harness locally replays qualified BALTOL02 behavior and uses previously characterized temporal policies only to create valid difficult research origins.

## Closure

`CLOSED_CONDITIONAL_GAIN_NOT_LIVE_JUSTIFIED`
