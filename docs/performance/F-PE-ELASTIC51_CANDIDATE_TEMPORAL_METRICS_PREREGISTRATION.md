# F-PE-ELASTIC51 — candidate temporal metric characterization preregistration

Date: 2026-09-29

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
- F-PE-ELASTIC49 qualified Reference temporal identity gate;
- F-PE-ELASTIC50 qualified finite localized full-half discrepancy.

Parent postimage:
`research/f-pe-elastic50-full-half-discrepancy@0a7cdee1bc688ea0498da08686158938bb181e64`

Canonical authority at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

Which physically interpretable full-versus-two-half state metric behaves most
usefully as a candidate temporal-error observable for the difficult saturated
ELAS cases?

This workunit does not select an acceptance tolerance and does not change the
transaction policy.

## Architectural boundary

Preserve:
- solver / execution-policy separation;
- transactional state semantics;
- hard mass conservation;
- production Reference mode.

Affected architecture invariants:
- 7 transactional time steps;
- 13 mass conservation;
- 23 physical options versus numerical policy;
- 25 Reference mode remains available;
- 26 runtime diagnostics.

Expected effect: observation only.

## Frozen physical/numerical bank

Reuse the ELASTIC50 direct-solve bank exactly:
- real BRO profile `90116260`;
- 16-node variable grid;
- bottom mode 7;
- explicit-flux top boundary;
- default-MvG hydraulic fixture;
- OFF, FIXED_1E6 and GENERATED;
- h0 = 2 and 10 cm;
- delta = +/-0.05 cm/day;
- start dt = 0.015625 day;
- retry scale 0.5;
- retry indices 0 through 8.

Only points where full, half1 and half2 all converge contribute metric values.

## Candidate metrics

For full state F and final two-half state H:

1. `H_INF`
   `max_i |h_F(i)-h_H(i)|` in cm.

2. `H_RMS_DZ`
   `sqrt(sum_i dz_i * (dh_i)^2 / sum_i dz_i)` in cm.

3. `THETA_INF`
   `max_i |theta_F(i)-theta_H(i)|`.

4. `STORAGE_L1`
   `sum_i dz_i * |theta_F(i)-theta_H(i)|` in cm water.
   This does not allow node-local cancellation.

5. `STORAGE_SIGNED`
   `abs(sum_i dz_i * (theta_F(i)-theta_H(i)))` in cm water.
   This observes bulk water-storage disagreement.

Also record the ratios:
- `STORAGE_L1 / max(abs(storage_full), abs(storage_half))`;
- `STORAGE_SIGNED / max(abs(storage_full), abs(storage_half))`;

when the denominator is finite and positive.

No threshold is preregistered.

## Evaluation criteria

For each regime/state/forcing sequence with at least three fully converged
retry-ladder points, characterize:

- monotonicity under decreasing dt;
- location/dominance of the discrepancy;
- cancellation ratio
  `STORAGE_SIGNED / STORAGE_L1`;
- separation between OFF, FIXED_1E6 and GENERATED.

A candidate is considered structurally promising only if:
- it is finite and physically interpretable;
- it does not turn roundoff-level bulk conservation into a large error;
- its retry-ladder behavior is more regular than the current exact-identity
  gate.

No candidate is admitted or selected as production policy in ELASTIC51.

## Hypotheses

H1. `STORAGE_SIGNED` remains near machine/balance noise for active-ELAS
converged pairs, confirming that exact-state rejection is not a bulk-mass
signal.

H2. `STORAGE_L1` exposes local elastic redistribution that is hidden by signed
storage cancellation.

H3. `H_INF` and `H_RMS_DZ` are surface-dominated and may be non-monotone
under decreasing dt in active ELAS.

H4. A water-storage-based metric is more physically interpretable for active
ELAS than bit identity alone, but ELASTIC51 will not choose a tolerance.

## Gates

A1. Same 108 direct comparison points execute.

A2. Metric values are emitted only when full, half1 and half2 converge.

A3. Every emitted metric is finite and nonnegative.

A4. Signed storage discrepancy is bounded above by unsigned storage discrepancy
within roundoff allowance.

A5. O0/O2 metric values and classifications agree exactly.

A6. No forcing, boundary, solver, constitutive, retry or tolerance change from
ELASTIC50.

A7. Zero `src/**` production changes.

## Decision

ELASTIC51 is research-only.

A qualified result may justify a later metric-design/falsification workunit.
It does not authorize replacing `fmr_serialized_temporal_identity`, changing
`temporal_tolerance`, or altering production timestep policy.
