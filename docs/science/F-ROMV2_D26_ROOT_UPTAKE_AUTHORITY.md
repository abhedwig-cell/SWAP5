# F-ROMV2 D26 — root-uptake authority reconciliation

**Decision:** `UNSTRESSED_TOTAL_UPTAKE_ACCOUNTING_PREFLIGHT_AUTHORIZED_NATIVE_FMC_TRAJECTORY_ET_HELD_PENDING_STATE_UPDATE_ORACLE`

D26 closes the authority question that follows the positive D24/D25 hydraulic
cost-fidelity result.

## Why the models must not be forced into pointwise sink equivalence

The current SWAP5 restricted root-water uptake route is the F-CI31
macro-Feddes process. Potential transpiration is distributed over rooted nodes
by the prescribed cumulative root fraction and is reduced nodewise from the
committed pressure-head state.

HYDRO-MEMORY DYN01 independently demonstrated the current composition:

- 4 mm d-1 reference ET -> 0.4 cm d-1 potential transpiration;
- the wet h=-75 cm state consumes the full demand;
- a dry rooted state reduces actual uptake under the same atmospheric demand;
- evaluation is stateless and deterministic.

The modern primary FMC authority is different. Ogden et al. (2015),
doi:10.1002/2015WR017126, specifies a root-zone depth and removes water from the
right-most water-containing finite-water-content bin, i.e. preferentially from
the wettest/lowest-capillarity available water, until demand is satisfied.

The same paper explicitly notes that this differs from a spatial root
distribution and that the distinction can materially change soil-water
profiles, infiltration and runoff.

Therefore D26 freezes the following comparison rule:

> Common atmospheric demand, common physical root-zone extent, total actual
> uptake and mass balance may be compared directly. Pointwise root-sink fields
> are model structure and are not required to be equal.

A prescribed identical sink can still be used later as a named
transport-isolation experiment, but it is not faithful/native FMC root uptake.

## Literature lineage

The 2008 discrete-water-content precursor describes ET according to a root
distribution. The later 2015 general FMC formulation is more explicit and is
the current D11/D12 primary process authority for this workstream.

The 2015 paper also reports an eight-month rainfall + ET loam experiment. Its
native ET stress construction is not imported into D26. Drought stress and
seasonal ET remain separate future questions.

## Secondary implementation oracle

The University of Wyoming DataCorral archive M2WC70 is linked directly to the
2015 paper and is described as containing the authors' C implementation and the
eight-month rainfall/ET case. The repository metadata marks the archive CC0 /
public domain.

The resource is identified but could not be materialized through the current
tool route.

D26 therefore refuses to invent the detailed composite
surface-front/falling-slug/groundwater-front withdrawal update that is not
fully explicit in the prose description.

## D27 authority

D27 may execute only a synthetic, unambiguous finite-volume accounting
preflight:

- B01 homogeneous hydraulic identity;
- 200 FMC bins;
- 10 s interval;
- 30 cm root zone, inherited from the already-qualified three-node DYN01
  geometry on the R16 10 cm grid;
- potential transpiration 0.4 cm d-1;
- wet, bin-aligned initial state that is safely outside Feddes drought stress;
- no rainfall, evaporation, runoff or groundwater/surface evolution;
- FMC withdrawal from the right-most water-containing bin;
- exact finite-volume root-zone and whole-column mass ledger.

The preflight must show that SWAP and FMC remove the same **total** water depth
while explicitly recording that their spatial extraction structures differ.

Even a positive D27 does not authorize a root-active FMC trajectory. That
requires the native composite-state update to be tied to primary or traceable
secondary implementation authority.

## Held claims

D26 does not qualify:

- native FMC root-active trajectories;
- drought stress feedback;
- seasonal ET;
- drought memory/recovery;
- application acceptance;
- formal performance;
- production ROM.

Production ROM remains unauthorized.
