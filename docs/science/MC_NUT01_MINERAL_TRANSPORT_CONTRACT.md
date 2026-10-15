# MC-NUT01 bounded mineral transport

Proposed successor to canonical `ee2d84498bec23c55449f5d7fd8ebd9ecb7bfdde`.
Donor PR #1117 at `b6b894513fcdcf66e94824742c129616ddd7aed1` supplies only
three process providers: inventory, storage conversion and analytical transport.
Its broad production/admission claims are not inherited.

One private owner contains aggregate NH4/NO3 and unchanged FOM/biomass/humus
stores. Organic N is derived from immutable fractions, never duplicated.
NH4 storage includes linear sorption; NO3 storage is water only. Units are m,
day, kg N/m2, kg N/m3, kg soil/m3 and m3/kg for sorption. The explicit N volume
is the complete modeled column, using thickness-weighted water content. This
is not a claim to reproduce historical strict-less-than layer selection.

The production profile advances exactly one day. It uses the B1.11
`Wofost_SoilWaterN` analytical daily solution with zero production, reaction
rates and root N extraction (TCSF=0). Root **water** extraction remains active.
All accepted hydraulic substeps contribute to the daily carrier. External
bottom/lateral concentrations remain distinct. Simultaneous external inflow
and outflow is rejected in this bounded profile because historical daily
net-water aggregation aliases that case. Top flux, ponding, macropores,
SSDI, snow, heat and general salt stores are excluded. No crop N, organic
turnover, nitrification, denitrification, amendments or general-solute capability
is promoted by this work.

The owner accepts only finite bounded inputs: depth 1e-3..100 m, water fraction
1e-4..1, bulk density 0..4000 kg/m3, sorption 0..1 m3/kg, N masses 0..100 kg/m2,
organic densities 0..1000 kg/m3 and N fractions 0..1. Concentrations are bounded
by 1e6 kg/m3. These bounds prevent arithmetic overflow before physical checks.
Whole-N balance is hard at 1e-12 times max(1, inventories, external transfers).
Water closure remains 1e-10 cm. Failure leaves committed water and N unchanged.
Clocks, revisions, immutable configuration and water endpoints are bound to
opaque and same-platform CRC disk restart. The existing water owner retains
all pressure, water, lineage, revision and temporal-history authority.

Independent process tests compile four real production providers and compare
against the literal pinned historical `SWAP/wofost_soil_watern.f90`, SHA256
`b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722`.
A targeted actual Full Richards composition is required before qualification.
No shared water kernel or existing matrix route is changed. Broader evidence
is inherited only for unchanged dependencies; no new blanket F-CI PASS is claimed.
The retired long highest-low-air gate remains NOT_SELECTED_POLICY.
