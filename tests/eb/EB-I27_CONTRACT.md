# EB-I27 — Accepted outer-substep sensible-boundary aggregation

## Qualified question

Can multiple already accepted EB-I25 external-full/half sensible-boundary publications be aggregated across consecutive outer committed runtime transactions without re-executing physics, weakening accepted-state provenance, or turning incomplete thermal evidence into a complete boundary?

## Bounded production change

EB-I27 adds a non-executing runtime aggregation layer over immutable `eb_i25_sensible_boundary_publication_t` inputs. It does not call `run_trial`, does not own a transaction, does not mutate committed state, and does not alter Richards, soil-temperature, timestep, retry or commit semantics.

The aggregator accepts only a sequence containing at least two EB-I25 publications. Every input must already be ready and runtime-complete, and must represent exactly:

- one canonical committed outer transaction (`accepted_substeps() == 1`);
- two accepted internal half-trajectory samples (`carrier_sample_count() == 2`);
- an EB-I25 top status of qualified two-half inflow or exact-zero transport.

Model-certificate single-step inheritance is deliberately not mixed into this capability. Accepted external-full/half outflow, missing donor evidence, snow-active publication, carrier failure and every other incomplete EB-I25 top status fail closed.

## Sequence provenance

For the complete accepted outer sequence EB-I27 requires:

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

No rejected or discarded trial can enter EB-I27 independently: EB-I27 has no trial-facing input and consumes only ready EB-I25 accepted publications.

## Failure semantics

EB-I27 publishes no ready aggregate when:

- fewer than two outer publications are supplied;
- an input is not a ready EB-I25 publication;
- an input is not exactly one accepted outer commit with two accepted half samples;
- an input sensible boundary is incomplete;
- top transport is outside the already qualified EB-I25 inflow/zero surface;
- column, lineage, revision, time or reference-temperature provenance is discontinuous;
- any aggregated numeric value is non-finite.

A failed EB-I27 aggregation does not roll back already committed physical transactions. That is intentional: EB-I27 is a read-only accepted-publication aggregator, not a transaction owner.

## Required owner evidence

Owner qualification must demonstrate at O0 and O2:

- two consecutive real `TX_TEMPORAL_EXTERNAL_FULL_HALF` EB-I25 transactions commit from one initial state;
- revisions progress 0 -> 1 -> 2 and intervals are contiguous;
- each outer transaction exposes exactly two accepted half samples;
- EB-I27 reports two accepted outer commits and four accepted internal half samples;
- each boundary energy component equals the sum of the two accepted I25 publications;
- accepted top liquid inflow equals the sum of the two accepted I25 publications;
- one-input aggregation fails as insufficient;
- reversed order fails revision/time provenance;
- duplicate input fails revision/time provenance;
- an incomplete EB-I25 input fails closed and does not produce a ready aggregate;
- O0/O2 semantic output identity.

## Hard nonclaims

EB-I27 does not qualify accepted external-full/half top liquid outflow sensible transport, mixed inflow/outflow top transport, snow or melt thermal provenance, or model-certificate/external-full-half route mixing. It does not add a multi-transaction rollback guarantee. It does not publish or qualify a whole-column sensible-energy storage residual. It does not add radiation, latent heat, vapor energy, freeze/thaw enthalpy, snow phase-change closure, pressure/chemical/salinity enthalpy, or a complete SWAP5 Energy Balance.

Owner qualification is not independent qualification and is not canonical admission.

## Identifier provenance

This capability was initially bootstrapped under the working label `EB-I26`. During reconciliation, an independently active workunit `work/eb-i26-top-liquid-outflow-sensible-transport` was found to own `EB-I26`. The outer committed-substep aggregation capability was therefore renumbered to `EB-I27` before owner qualification. The renumbering changes no scientific or runtime semantics and does not absorb any top-liquid-outflow semantics.

The consecutive accepted-Richards owner fixture is inherited from the already owner-verified F-KT10 transaction-history composition surface. EB-I27 adds restricted soil-temperature state only as required by the sensible-energy runtime; it does not change the F-KT10 hydraulic controls.

F-KT22 later changed the shared serialized reference backend. EB-I27 reconciles that delta by locking the original backend blob, the admitted F-KT22 backend blob, and the immutable F-KT22 close checkpoint whose qualification jobs record `eb-i25-preservation: PASS`. All other inherited EB-I23/I24/I25 authority blobs remain unchanged.
