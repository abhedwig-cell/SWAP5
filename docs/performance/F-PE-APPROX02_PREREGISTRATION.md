# F-PE-APPROX02 — practical Richards solve-effort frontier

Date: 2026-09-26

Status: `PREREGISTERED_NOT_STARTED`

Predecessor:
`F-PE-APPROX01 — practical MultiSWAP tangent cadence`

Parent production-shaped candidate:
`F-PE-APPROX01 A1 — bounded same-origin tangent cache`

## Purpose

After qualifying a bounded approximation in the coupling-response tangent, measure the next larger performance frontier in the physical Richards solve itself.

APPROX02 asks:

**how much end-to-end runtime can be removed by reducing numerical solve effort while keeping hydrological deviations inside explicit practical envelopes?**

This workunit is intentionally separate from A1.

## Default authority

The exact canonical / admitted stack remains the reference.

Any APPROX02 mode must be:
- explicit;
- opt-in;
- default OFF;
- fully diagnosable;
- compared against the same exact forcing sequence and coupling setup.

## First research axis

The first phase maps numerical effort before selecting one production candidate.

Candidate controls include:

- nonlinear head convergence tolerance;
- compartment / total balance tolerances;
- maximum Newton / backtracking effort;
- temporal indicator budget;
- minimum / maximum practical substep size where production configuration exposes it.

Do not vary all settings at once initially.

Begin with one-dimensional sweeps around current production settings, then combine only levers that show independently useful speedup/error tradeoffs.

## Required measurements

For every candidate:

### Runtime
- repeated solver runtime;
- application / coupled runtime where available;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- accepted substeps;
- retries / backtracking.

### Hydrological deviation
- pressure head profile;
- water content profile;
- bottom flux;
- cumulative bottom exchange;
- storage change;
- mass residual;
- root-zone state where active.

### Coupled response
For MODFLOW-shaped tests:
- final groundwater head;
- coupled iteration count;
- cumulative interface exchange;
- convergence/failure rate.

## Error framework

Report both instantaneous and accumulated error.

A candidate may not be admitted solely because one endpoint matches.

At minimum distinguish:

- state error;
- flux error;
- cumulative exchange error;
- mass-balance error;
- coupled groundwater-head error.

## Initial practical envelope

No final tolerance is preregistered yet.

The first phase must produce the speedup/error frontier before selecting an envelope.

The strategic expectation is that percent-level hydrological deviations may be acceptable for the intended large-N coupled use case, but the data must determine which variables can tolerate that and which cannot.

## Admission rule

A production-shaped APPROX02 candidate may advance only if:

1. runtime gain is materially larger than remaining exact-P0/P1 opportunities;
2. physical deviations are bounded and interpretable;
3. mass balance remains within a separately declared envelope;
4. failure/retry behavior does not worsen materially;
5. exact default behavior remains unchanged;
6. the approximate mode has explicit provenance.

## Rejection rule

Reject a numerical-effort lever if:
- errors accumulate unexpectedly;
- the speedup is small;
- gains depend on unstable solver behavior;
- mass balance degrades disproportionately;
- or the lever changes scientific interpretation in regimes that matter.

## Relationship to existing configuration studies

Historical configuration studies and external reports may later be reconciled into this frontier, but repository measurements remain the admission authority.

APPROX02 begins from the current SWAP5 production postimage rather than importing historical speedup claims.
