# F-PE-LIVE01 — required live-trial cost rebaseline

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-TEMPORAL08 / PR #655`

Parent head at branch creation:
`7c363f777794d5d1f99fe430ec3507ec7c3d8bb6`

Branch:
`work/f-pe-live01-required-trial-rebaseline`

## Trigger

F-PE-SOLVE01 closed the discarded-trial elimination route for the current live MODFLOW6 authority.

The decisive application-level result was:

- 8/12 difficult live groups required only two exact SWAP trials;
- 4/12 required four exact trials;
- 0/12 required five or more;
- E4 reduced exact trials from 32 to 18 but increased aggregate live runtime by about 6.1%.

Therefore the main performance target is no longer the number of discarded trials.

It is the cost of the 2-4 exact SWAP trials that live coupling actually requires.

TEMPORAL08 has meanwhile production-admitted the bounded history-aware c=0.65 temporal policy. LIVE01 therefore starts from the current TEMPORAL08 production lineage rather than the older PROFILE06/SOLVE01 research parent.

## Primary question

Where is wall-clock time spent inside the exact SWAP trials required by the live difficult MODFLOW6 coupling, on the current production-shaped c=0.65 stack?

## Scope

Observation-only.

No `src/**` modification is allowed.

LIVE01 may add:

- research/profiling harnesses;
- diagnostics collection in copied/instrumented test seams;
- CI workflows;
- result and closeout documentation.

Any optimization discovered here must be opened as a separate preregistered workunit.

## Frozen live matrix

Reuse the difficult live matrix from SOLVE01 P2B:

- B01 wet, h0 = -10 cm, history -10% and +10%;
- B01 mid, h0 = -75 cm, history -10% and +10%;
- B12 wet, h0 = -10 cm, history -10% and +10%;
- O05 wet, h0 = -10 cm, history -10% and +10%;
- O14 wet, h0 = -10 cm, history -10% and +10%;
- O14 mid, h0 = -75 cm, history -10% and +10%.

Total: 12 groups.

Use exact live coupling only.

No E4/EH/EF approximation arms.

## Production baseline

Use current TEMPORAL08 bounded groundwater behavior:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

where the production profile is admitted.

Do not compare against c=0.50 as the primary baseline.

c=0.50 may be reported only as historical attribution if already available from frozen evidence.

## Measurements

For every exact live SWAP trial record at minimum:

- wall-clock duration;
- transaction calls;
- accepted substeps;
- total attempts;
- retries;
- solver rejections;
- temporal rejections;
- nonlinear iterations;
- Jacobian builds where observable;
- linear solves where observable;
- headcalc calls where observable;
- backtracking attempts;
- internal retries;
- response-tangent fresh/reuse status where applicable;
- prescribed head displacement from captured origin;
- final q and response tangent;
- whether the trial became the committed candidate.

At coupled-interval level record:

- MODFLOW corrector count;
- exact SWAP trial count;
- total SWAP-trial wall-clock;
- total prepared-solve/coupled-loop wall-clock;
- final head;
- final q;
- final residual;
- ledger/publication status.

## Required decomposition

LIVE01 must distinguish at least:

1. temporal retry/substep work;
2. nonlinear iteration work;
3. accepted-direction/tangent work;
4. constitutive/headcalc work where observable;
5. fixed orchestration/transaction overhead.

Do not infer component cost by summing unrelated historical microbenchmarks.

## Output

Produce a ranked cost attribution for the actual live workload.

The ranking must be based on measured contribution to the current live path, not on theoretical optimization potential.

For each major cost family report:

- observed count/frequency;
- measured or bounded wall-clock contribution;
- fraction of total exact-trial wall-clock where identifiable;
- whether the cost is physically necessary, numerically necessary, or implementation overhead;
- whether a separate optimization workunit is justified.

## Advancement rule

LIVE01 does not admit an optimization.

It closes when the current live exact-trial cost is sufficiently localized to choose the next performance workunit without guessing.

A successor is justified only if the target is expected to affect a substantial fraction of the 2-4 exact trials that P2B showed to be unavoidable.

## Strategic constraint

Do not reopen discarded-trial solve elimination unless future live evidence shows materially higher corrector demand.

The post-SOLVE01 optimization priority is:

`cheapen unavoidable live trials > reduce retries inside those trials > remove redundant exact-path work > revisit solve elimination only if demand changes`.
