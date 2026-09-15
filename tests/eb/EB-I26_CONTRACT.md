# EB-I26 — Accepted outer-substep sensible-boundary aggregation

## Qualified question

Can multiple already accepted EB-I25 external-full/half sensible-boundary publications be aggregated across consecutive outer committed runtime transactions without re-executing physics, weakening accepted-state provenance, or turning incomplete thermal evidence into a complete boundary?

## Bounded production change

EB-I26 adds a non-executing runtime aggregation layer over immutable `eb_i25_sensible_boundary_publication_t` inputs. It does not call `run_trial`, does not own a transaction, does not mutate committed state, and does not alter Richards, soil-temperature, timestep, retry or commit semantics.

The aggregator accepts only a sequence containing at least two EB-I25 publications. Every input must already be ready and runtime-complete, and must represent exactly:

- one canonical committed outer transaction (`accepted_substeps() == 1`);
- two accepted internal half-trajectory samples (`carrier_sample_count() == 2`);
- an EB-I25 top status of qualified two-half inflow or exact-zero transport.

Model-certificate single-step inheritance is deliberately not mixed into this capability. Accepted external-full/half outflow, missing donor evidence, snow-active publication, carrier failure and every other incomplete EB-I25 top status fail closed.

## Sequence provenance

For the complete accepted outer sequence EB-I26 requires:

- one column id for all inputs;
- one current lineage id for all inputs;
- exact committed revision chaining: each next origin revision equals the preceding committed revision;
- contiguous physical intervals: each next `t0` equals the preceding `t1` under the existing finite machine-precision time comparison;
- one mass-carried sensible-energy reference temperature across the sequence;
- complete finite sensible-boundary values on every input.

The aggregate origin revision and time are taken from the first accepted publication. The aggregate committed revision and end time are taken from the last accepted publication. With `N` accepted outer publications, the final revision must equal the origin revision plus `N`.

## Aggregation semantics

Only already accepted quantities are summed:

- top conductive sensible energy into the column;
- top advective sensible energy into the column;
- bottom conductive sensible energy outward;
- bottom advective sensible energy outward;
- accepted top liquid inflow;
- accepted internal half-sample count.

The aggregate records both the number of accepted outer committed transactions and the total number of accepted internal half samples. For this contract the latter must equal exactly twice the former.

No rejected or discarded trial can enter EB-I26 independently: EB-I26 has no trial-facing input and consumes only ready EB-I25 accepted publications.

## Failure semantics

EB-I26 publishes no ready aggregate when:

- fewer than two outer publications are supplied;
- an input is not a ready EB-I25 publication;
- an input is not exactly one accepted outer commit with two accepted half samples;
- an input sensible boundary is incomplete;
- top transport is outside the already qualified EB-I25 inflow/zero surface;
- column, lineage, revision, time or reference-temperature provenance is discontinuous;
- any aggregated numeric value is non-finite.

A failed EB-I26 aggregation does not roll back already committed physical transactions. That is intentional: EB-I26 is a read-only accepted-publication aggregator, not a transaction owner.

## Required owner evidence

Owner qualification must demonstrate at O0 and O2:

- two consecutive real `TX_TEMPORAL_EXTERNAL_FULL_HALF` EB-I25 transactions commit from one initial state;
- revisions progress 0 -> 1 -> 2 and intervals are contiguous;
- each outer transaction exposes exactly two accepted half samples;
- EB-I26 reports two accepted outer commits and four accepted internal half samples;
- each boundary energy component equals the sum of the two accepted I25 publications;
- accepted top liquid inflow equals the sum of the two accepted I25 publications;
- one-input aggregation fails as insufficient;
- reversed order fails revision/time provenance;
- duplicate input fails revision/time provenance;
- an incomplete EB-I25 input fails closed and does not produce a ready aggregate;
- O0/O2 semantic output identity.

## Hard nonclaims

EB-I26 does not qualify accepted external-full/half top liquid outflow sensible transport, mixed inflow/outflow top transport, snow or melt thermal provenance, or model-certificate/external-full-half route mixing. It does not add a multi-transaction rollback guarantee. It does not publish or qualify a whole-column sensible-energy storage residual. It does not add radiation, latent heat, vapor energy, freeze/thaw enthalpy, snow phase-change closure, pressure/chemical/salinity enthalpy, or a complete SWAP5 Energy Balance.

Owner qualification is not independent qualification and is not canonical admission.
