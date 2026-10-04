e separate stateful Rutter capability;
2. F-MIG431-INT12-P0 for method-neutral immutable source-window interception aggregates with accepted progress, retry and restart provenance;
3. F-MIG431-INT12-C for the existing `SWINTER=1` daily aggregate route;
4. F-MIG431-INT12-D, PR #1010, canonical merge `23a5768771a93a338daba78ab117682ee1e459f2`, for `SWINTER=2` Gash daily `SWMETDETAIL=0`;
5. F-MIG431-INT12-E, PR #1011, canonical merge `0fc427f63cffab666014129641c864ccd65983f0`, for `SWMETDETAIL=1` non-Rutter record continuation shared by `SWINTER=1/2`.

The admitted semantics are:

- `SWINTER=1` and `SWINTER=2` interception physics produce source-window aggregates rather than persistent physical canopy-storage state;
- Gash preserves the B1.11 equation and legacy branch ordering, including the historical `grai` saturation comparison;
- numerical retries do not reevaluate nonlinear daily interception physics on smaller hydraulic spans;
- accepted source-window progress is transactional and restartable through P0;
- daily rain/sprinkling partition, the legacy DivIntercep threshold, snow-disable gate and wet-canopy potential-transpiration composition are qualified;
- detailed meteorology uses record-weighted daily interception and an explicit accepted `restint` continuation within the source day;
- detailed `restint` is reset to zero at every new detailed-meteo source day and is therefore not physical or multi-day canopy storage;
- mid-day restart persists source-day identity, next-record cursor and accepted `restint`;
- rejected trials advance neither interception progress nor detailed-record continuation state.

Final INT12-E admission-head qualification passed in run `37152387427`; INT12-D preservation passed in `37152387486`; P0 preservation passed in `37152387442`.

Within the non-Rutter `SWINTER=1/2` interception scope, no known selector, retry, restart or precipitation-partition capability gap remains. `SWINTER=3` Rutter remains a separate stateful capability and is not subsumed by this closure.

The INT13 work branch now composes Rutter canopy storage and INT12 source-window progress into the production FMR physical-state candidate. Local O0/O2 source-window and production-transaction tests pass, including Richards retry identity, rejected-trial rollback, restart carrier registration, root-sink composition and hard mass closure. This is work-branch evidence only: `SWINTER=3` is not yet canonically admitted, and the family must not be described as fully closed until persisted qualification and canonical merge. The bounded local envelope excludes irrigation/sprinkling, Snow, Black/Boesten, macropore and surface-water/RFM combinations; see `integration/audits/F-MIG431-INT13_STATUS.json`.


## Compensated root uptake: PPA-WU05-D2/D3 (2026-10-04)

Jarvis (PR #1012, canonical merge `4fd57c8c8`) and Walsum (PR #1013,
canonical merge `a34c87db9`) are separately admitted within the existing Feddes
root-sink chain, optionally composed with independently admitted Bartholomeus
oxygen. The sole root-water mass owner remains unchanged. Accepted transpiration
now reports the final transformed sink through the existing transaction result.
Walsum derives its dynamic ALPHACRIT from typed current centimetre geometry,
including the full bottom of a partially rooted node.

See [canonical closeout](../audits/PPA_WU05D_D2_D3_CANONICAL_CLOSEOUT.md) for
qualification, exact scope, legacy-source limitations and the remaining D4/D5 gaps.
This does not admit salinity, frost, MICRO or general coupling combinations.
