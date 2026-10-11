# F-PE-PROFILE05 measurement plan

Date: 2026-09-26

Status: `OBSERVATION_ONLY`

## Primary comparison

Measure four modes on the same postimage:

1. exact default;
2. A1 only;
3. A2C only;
4. A1 + A2C.

The combined arm is the primary practical-stack measurement.

## Coupled end-to-end gate

Use the existing FGC44 live SWAP + MODFLOW6 route.

For each arm record:

- coupling-loop wall time;
- final MODFLOW head;
- final SWAP groundwater exchange flux;
- cumulative accepted interface ledger exchange;
- coupled iteration count;
- fresh tangent count;
- reused tangent count.

Run at least three independent replicas of the four-arm comparison.

The exact arm is the endpoint authority.

A1 and A2C are already separately qualified. PROFILE05 nevertheless verifies endpoint behavior on the combined postimage rather than assuming compositional identity.

## Application-shaped gate

Use the production application sequence already used by APPROX02.

Compare exact default against A2C for local Richards work and mass accounting, and add A1 only where the application path actually requests directional tangents.

Do not claim A1 application benefit from a workload that does not exercise the tangent path.

## Attribution measurements

Reuse existing production-shaped instrumentation where possible:

- PROFILE04 repeated Reference timing;
- PROFILE04 directional timing;
- A1 fresh/reuse counts;
- A2C nonlinear iteration / HeadCalc counters;
- current transaction accepted-substep/retry counters.

PROFILE05 may add observation-only test harnesses and workflow glue.

It must not modify `src/**`.

## Timing interpretation

For each four-arm coupled replica report raw times and ratios.

Primary ratios:

- A1 / exact;
- A2C / exact;
- stack / exact;
- stack / A2C;
- stack / A1.

Do not infer the stack result by multiplying or adding the separately measured A1 and A2C ratios.

For sub-millisecond loops, timing spread is expected. The robust evidence is:

- direction of all replicated stack-vs-exact measurements;
- median stack-vs-exact ratio;
- endpoint identity;
- work counters explaining any speed change.

## Hotspot decision

After the combined practical-stack measurement, re-run the current repeated Reference and directional decompositions.

A next workunit may be opened only for a measured remaining hotspot.

No implementation change is allowed in PROFILE05.
