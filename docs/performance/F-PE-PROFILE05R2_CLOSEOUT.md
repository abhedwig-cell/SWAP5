# F-PE-PROFILE05R2 closeout — post-repair practical stack

Date: 2026-09-26

Status: `CLOSED_MEASURED_STACK_POSITIVE_A1_DOMINATED`

PR:
`#638 — F-PE-PROFILE05R2: post-repair practical-stack rebaseline`

Branch:
`work/f-pe-profile05r2-post-repair-stack`

Parent:
`F-PE-REPAIR01`

## Closure

PROFILE05R2 successfully restored the observation-only practical-stack rebaseline after the exact-route ownership repair.

The direct repeated live coupled result is:

- A1 + A2C versus exact:
  - 13/15 speed-positive cycles;
  - median speedup about 3.39%;
  - mean speedup about 3.29%.

Endpoint and ledger behavior are preserved.

## Attribution

The measured stack gain is A1-dominated.

A1 alone:

- 15/15 speed-positive;
- median speedup about 5.38%.

A2C alone:

- 8/15 speed-positive;
- median speedup about 0.57%.

Stack versus A1:

- speed-positive in only 5/15 cycles;
- median incremental speedup about -3.00%.

Therefore there is no evidence that A2C adds coupled runtime benefit in this very short two-iteration FGC44 workload.

## Supporting evidence

A2C remains robust and application-shaped timing remains speed-positive in the current fixture, with exact mass/accounting preservation.

However, that application sequence shows no reduction in nonlinear iteration, substep or retry counters.

It is not used to infer a broad A2C solve-effort gain.

## Remaining hotspot

The postimage decomposition remains dominated by the Reference backend:

- approximately 90.4% of application runtime;
- approximately 9.6% wrapper.

The direct directional route remains approximately 1.74x the direct Reference cost, but A1 already targets repeated tangent work.

## Decision

Do not optimize the tiny FGC44 two-iteration coupling loop further.

The next performance workunit should use production-shaped Richards workloads with genuine nonlinear difficulty and enough repeated solve work to determine:

- where A2C actually reduces nonlinear/constitutive/linear effort;
- whether A1 and A2C become complementary when the solve is harder;
- which remaining Reference backend component dominates after both practical modes.

Any implementation change requires a new preregistered workunit.
