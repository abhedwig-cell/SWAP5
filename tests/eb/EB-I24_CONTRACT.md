# EB-I24 — Accepted top liquid sensible-inflow runtime materialization

## Purpose

EB-I24 binds one previously missing EB-I22 boundary category on a deliberately bounded accepted runtime route: top liquid-water sensible energy entering the soil column.

Canonical base: `1ef995e682cbc0fbbce8b68281646b0de1bbbcd3`.

EB-I24 replays the source-neutral explicit external-liquid-water donor-temperature rule previously exercised by EB-I08 and composes it with the already admitted EB-I23 same-call accepted sensible-boundary publication. Historical I08/I10R2 branches are evidence only; they are not treated as canonical authority.

## Qualified candidate semantics

A top advective sensible-energy value may be materialized only when all of the following hold:

1. the transaction completed and committed;
2. the inherited EB-I23 accepted publication is ready and matches column, revision and interval provenance;
3. exactly one substep was accepted, so `backend%observation()` is the accepted whole-interval solve observation rather than only the final member of a multi-substep trajectory;
4. snow is inactive;
5. the accepted solver observation is converged and has a finite top flux;
6. canonical top flux is non-positive: negative is liquid inflow and exact zero is known zero transfer;
7. for positive inflow amount, an explicit finite external liquid-water donor temperature is supplied;
8. the liquid sensible-enthalpy parameters are ready and their reference temperature equals the inherited EB-I22/I23 mass-carried reference.

For the snow-inactive single-substep route, accepted liquid inflow depth is

`inflow_cm = - accepted_top_flux * (t1 - t0)`

for `accepted_top_flux < 0`.

Sensible inflow energy is evaluated only by the already canonical `evaluate_liquid_water_sensible_transport` law. EB-I24 does not introduce another heat-capacity or reference-temperature law.

Exact zero transport may publish an available zero sensible contribution without donor temperature. This is an observed accepted zero, not missing data repaired to zero.

## Fail-closed cases

The top advective category remains unavailable for:

- missing or invalid external donor temperature when accepted liquid inflow is positive;
- positive top flux (water leaving the soil), because its donor is soil-side and no accepted local-liquid donor-temperature authority is qualified here;
- snow-active execution, because solver top flux then combines `base_top_flux` with snow melt and there is no single qualified donor-temperature provenance for that mixture;
- accepted multi-substep trajectories, because current `last_observation` is not an accepted whole-interval top-flux accumulator;
- rejected/uncommitted transactions;
- invalid accepted provenance or invalid energy-reference provenance.

## Evidence requirements

Owner qualification must demonstrate at minimum:

- accepted snow-inactive single-substep top inflow with explicit donor temperature materializes top sensible energy according to the canonical liquid-water transport law;
- on that bounded fixture, the inherited three I23 terms plus top advective term make the EB-I22 boundary object complete;
- missing top donor temperature remains unavailable rather than zero;
- top outflow cannot reuse the external inflow donor temperature;
- rejected trials publish no I24 result;
- O0 and O2 produce identical pass markers;
- inherited canonical authority blobs remain unchanged;
- the delta stays restricted to EB-I24 files plus the replayed generic donor-temperature module.

## Hard nonclaims

EB-I24 does **not** claim:

- a complete SWAP5 Energy Balance;
- whole-column sensible residual publication;
- top liquid sensible energy for snow/melt mixtures;
- top sensible energy for liquid outflow;
- accepted multi-substep top-water aggregation;
- radiation, latent heat, vapor energy, freeze/thaw enthalpy or snow phase-change closure;
- that air, prescribed surface, soil, precipitation, irrigation or ponding temperature can be substituted for an explicit donor-water temperature;
- that the historical EB-I08 or EB-I10R2 branch is itself canonical authority;
- canonical admission or independent qualification.

## Next capability exposed

The remaining structural runtime gaps are a rollback-safe accepted top-water/thermal carrier for multi-substep trajectories and a separate qualified soil-side donor-temperature authority for top liquid outflow (plus explicit snow/melt thermal provenance if that route is to be supported).
