# F-PE-APPROX03 — practical timestep / temporal-effort frontier

Date: 2026-09-26

Status: `PREREGISTERED_NOT_STARTED`

Predecessor:
`F-PE-APPROX02 — practical Richards solve-effort frontier`

Parent practical modes:
- `A1` bounded same-origin tangent cache;
- `A2C` strict-practical Richards convergence envelope.

## Purpose

Measure whether fewer temporal refinements / accepted substeps can deliver the next large end-to-end speedup while preserving hydrological behavior inside explicit practical envelopes.

APPROX03 is intentionally separate from A2C.

A2C changes local nonlinear convergence effort inside a solve.

APPROX03 changes how many solves/substeps are required over time.

## First research question

How does relaxing the temporal acceptance / substep refinement policy change:

- accepted substep count;
- nonlinear solve count;
- runtime;
- trajectory state;
- cumulative exchange;
- mass balance;
- coupled MODFLOW response?

## Initial axes

Start with one axis at a time:

1. model temporal-indicator head budget;
2. minimum practical substep duration where applicable;
3. bounded maximum substep / refinement depth if exposed by production configuration.

Do not simultaneously change nonlinear tolerances beyond the already qualified A2C envelope during the first temporal frontier.

## Reference modes

Measure against:

1. exact default temporal policy;
2. exact temporal policy + A2C active.

This separates temporal gains from already-qualified nonlinear convergence gains.

## Workloads

Use multi-step transient workloads where the exact reference actually performs temporal refinement.

At minimum cover:

- B01;
- B12;
- O05;
- O14;
- wet / mid / dry;
- one production application sequence;
- live SWAP + MODFLOW6 coupled qualification for any candidate that advances.

## Metrics

### Runtime / work
- wall-clock runtime;
- accepted substeps;
- rejected substeps / retries;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts.

### Hydrological deviation
- pressure-head profile;
- water-content profile;
- bottom flux;
- cumulative bottom exchange;
- storage change;
- canonical mass residual.

### Coupled response
- final MODFLOW head;
- coupling iteration count;
- cumulative interface exchange;
- failure / retry rate.

## Error policy

Do not select a temporal policy solely from endpoint agreement.

Temporal approximation must report:
- maximum transient state error;
- maximum stepwise flux error;
- cumulative exchange error;
- final state error;
- mass-balance error.

## Admission rule

A temporal candidate may advance only if:

1. it materially reduces accepted solve/substep work;
2. runtime gain is reproducible;
3. transient and cumulative errors remain bounded;
4. no new coupled robustness failures occur;
5. exact default behavior remains unchanged;
6. the practical mode is explicit, opt-in and diagnosable.

## Rejection rule

Reject a temporal lever if:
- it merely shifts work into retries;
- transient errors are large despite endpoint agreement;
- cumulative exchange bias grows monotonically;
- coupled convergence becomes less reliable;
- or runtime gain is too small to justify another approximation mode.

## Strategic note

APPROX03 should test whether temporal effort is still a major remaining cost after A1 + A2C.

If the remaining end-to-end runtime is already dominated by unavoidable physical solves or external MODFLOW work, APPROX03 may close without adding a new production mode.
