# F-PE-ELASTIC62 — representation-floor attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic62-representation-floor`

Qualified postimage:
`1ea0d63a5b9a616ad87fdbea68669d70bd83f3d3`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36681275147`

Job:
`109777039890`

Conclusion:
SUCCESS.

## Question

Are the six strict half1 total-balance failures from ELASTIC59-61 consistent
with the already-qualified P2E07 theta-input representation floor?

## Frozen cases

Exactly the six baseline strict half1 failures:
- profile 8016;
- h0 = -20 cm;
- delta = +0.035 and +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- half-step dt = 0.00048828125 day;
- compartment tolerance = 1e-12;
- total tolerance = 1e-12.

No numerical tolerance was changed.

## P2E07 diagnostic reproduced

Per node:

`floor_i = 0.5 * (spacing(theta_internal_i) + spacing(theta_base_i)) * dz_i / dt`.

ELASTIC62 reports:
- max local representation floor;
- conservative sum of local floors;
- integrated max/sum floor scales;
- max local residual;
- absolute total residual.

## Local residual result

All six max local residuals are at or below the P2E07 node-local
representation floor.

For delta +0.035:

`R_local = max_local_residual / max_local_floor = 0.92138671875`.

For delta +0.05:

`R_local = 0.919921875`.

Therefore:

`local_supported = 6 / 6`.

This independently reinforces the ELASTIC60 observation that the strict
per-compartment residual is already operating at a representation-scale floor.

## Total residual result

Using the explicitly conservative diagnostic

`sum_local_floors = sum_i floor_i`,

all six absolute total residuals are also below the aggregate representation
scale.

For delta +0.035:

`R_total = abs(sum residual) / sum_local_floors = 0.305615234375`.

For delta +0.05:

`R_total = 0.0774576822917`.

Therefore:

`total_supported = 6 / 6`.

This is a diagnostic upper-scale comparison only.

It does not establish that simple summation of local floors is the correct
production total-balance tolerance.

## Integrated depth scales

For all six cases:

max-node integrated representation floor:

`dt * max_local_floor = 4.44089209850063e-16 cm`.

Conservative summed integrated floor:

`dt * sum_local_floors = 6.66133814775094e-15 cm`.

Existing admitted BALTOL02 depth floor:

`2.8e-16 cm`.

Thus even the single largest node-local representation floor is about 1.59x
the admitted BALTOL02 depth floor for this heterogeneous profile/state.

The conservative aggregate floor is much larger, about 23.8x BALTOL02.

## Relation to BALTOL02

BALTOL02 remains valid production authority and is not changed by ELASTIC62.

At the frozen half-step dt:

`2.8e-16 / dt < 1e-12 cm/day`,

so the admitted effective rate remains the configured strict
`1e-12 cm/day`.

ELASTIC61 showed this is below the observed total residual floor in the six
cases.

ELASTIC62 now explains that discrepancy in the same representation-floor
framework that underpins P2E07/BALTOL01:

- local residuals lie within their node-local representation scales;
- the total residual lies within a conservative aggregation of those scales;
- the heterogeneous profile's representable depth scale exceeds the single
  historical BALTOL02 floor.

## Regime independence

OFF, FIXED_1E6 and GENERATED results are identical.

This is consistent with the unsaturated h0=-20 cm trajectory and confirms that
the diagnosed floor is not an elastic-storage-regime effect.

## Hypothesis outcome

H1, max local residual is at/below P2E07 local representation floor:
SUPPORTED, 6/6.

H2, total residual is at/below conservative sum of local floors:
SUPPORTED, 6/6.

H3, aggregate profile representation scale can exceed the single BALTOL02 depth
floor:
SUPPORTED, 6/6.

H4, regime independence:
SUPPORTED.

## Interpretation

ELASTIC60-62 now form a consistent causal chain:

1. the half1 solve stalls despite more nonlinear iterations;
2. the strict total-balance criterion is the causal accept/retry switch;
3. local residuals are already below their representation-resolution floor;
4. the total residual is also below a conservative profile-aggregate
   representation scale.

The remaining scientific question is therefore not whether the six cases need
more nonlinear iterations.

It is how a total-balance convergence criterion should aggregate
node-local representation floors in a heterogeneous column without weakening
the independent hard physical mass contract.

## Decision

Classification:

`QUALIFIED_PROFILE_AGGREGATE_REPRESENTATION_FLOOR_EVIDENCE`.

No production tolerance change is authorized.

The next bounded workunit should evaluate candidate aggregation rules for the
total-balance representation floor across the broader ELASTIC55 multi-profile
bank and compare them against:
- strict successes;
- known total-balance failures;
- BALTOL02 behavior;
- physical overlap/error authority.

A candidate aggregation rule must be qualified independently before any
production-policy proposal.
