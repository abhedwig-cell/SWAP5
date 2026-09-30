# F-PE-ELASTIC63 — total-balance representation-floor aggregation preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
`F-PE-ELASTIC62 — QUALIFIED_PROFILE_AGGREGATE_REPRESENTATION_FLOOR_EVIDENCE`

Parent postimage:
`research/f-pe-elastic62-representation-floor@9fa4601d178271d525b0fc148595e1f78a63be07`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

How should node-local P2E07 representation floors be aggregated for diagnosing
the total-balance residual of a heterogeneous Reference Richards column?

ELASTIC63 does not change any production tolerance.

## Frozen bank

Reuse exactly the four ELASTIC55 profiles:
- 11060;
- 10260;
- 8016;
- 3030.

Reuse exactly:
- the ELASTIC55 profile geometry and Staringreeks retention materialization;
- generated Ss;
- bottom mode 7;
- swkimpl=0;
- fixed-flux top boundary;
- h0 = -75,-20,+2,+10 cm;
- delta = -0.05,-0.035,+0.035,+0.05 cm/day;
- OFF, FIXED_1E6, GENERATED;
- nine-step dt ladder;
- configured compartment and total balance tolerances = 1e-12 cm/day.

No solve settings are changed.

## Diagnostic state

For each direct full solve and, where executed, first half solve, observe the
final internal Reference workspace irrespective of converged/retry status.

For each observed solve state compute the P2E07 node-local storage-input
representation floor:

`f_i = 0.5*(spacing(theta_internal_i)+spacing(theta_base_i))*dz_i/dt`.

Also record:
- max absolute local residual;
- absolute sum of residuals;
- solve status;
- max local residual node.

## Preregistered total-floor aggregation candidates

No candidate is tuned after results.

A_MAX:
`F_max = max_i f_i`.

A_RSS:
`F_rss = sqrt(sum_i f_i^2)`.

A_SUM:
`F_sum = sum_i f_i`.

Interpretation:
- A_MAX assumes only one node-level quantization contribution is limiting;
- A_RSS is a diagnostic intermediate scale and does not claim statistical
  independence;
- A_SUM is the deterministic worst-case no-cancellation bound.

For each solve compute:

`R_total_MAX = abs(sum residual)/F_max`;

`R_total_RSS = abs(sum residual)/F_rss`;

`R_total_SUM = abs(sum residual)/F_sum`.

Also compute local
`R_local = max(abs residual)/F_max`.

## Comparison classes

STRICT_SUCCESS:
solve converged under configured 1e-12 criteria.

RETRY_ADVISED:
solve returned retry-advised.

For RETRY_ADVISED further classify from the final internal residual:

LOCAL_ABOVE_STRICT:
`max(abs residual)>1e-12`.

TOTAL_ONLY_STRICT:
`max(abs residual)<=1e-12` and `abs(sum residual)>1e-12`.

OTHER_RETRY:
remaining retry-advised cases.

## Evaluation

For each aggregation candidate record:
- fraction of TOTAL_ONLY_STRICT states with R_total <= 1;
- fraction of LOCAL_ABOVE_STRICT states with R_total <= 1;
- fraction of STRICT_SUCCESS states with R_total <= 1;
- maximum R_total in each class.

A useful diagnostic total-floor aggregation should explain TOTAL_ONLY_STRICT
states without indiscriminately swallowing clearly local-residual failures.

No candidate is promoted to a tolerance in ELASTIC63.

## BALTOL02 comparison

For every observed solve report the admitted BALTOL02 effective rate:

`max(1e-12,2.8e-16/dt)`.

Record whether each retry would remain a retry under that existing rate floor
based on the observed residual snapshot only.

This is diagnostic replay, not an alternative solver execution.

## Gates

A1. Four profile IDs exactly reproduce ELASTIC55.

A2. All requested full solves execute; half1 is observed wherever the direct
fixture executes it.

A3. O0/O2 classifications and floor diagnostics agree.

A4. Every P2E07 floor and residual diagnostic is finite and nonnegative.

A5. ELASTIC62's six strict half1 cases reproduce their prior floor ratios.

A6. Zero `src/**` production changes.

## Decision

ELASTIC63 is observation-only.

It may identify a promising aggregation rule for a later independent
qualification.

It does not authorize:
- changing BALTOL02;
- changing solver tolerances;
- changing transaction mass acceptance;
- changing temporal acceptance.
