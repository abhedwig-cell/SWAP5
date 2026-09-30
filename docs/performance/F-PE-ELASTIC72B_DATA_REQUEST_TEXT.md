# F-PE-ELASTIC72B — data request text

Date: 2026-09-30

Target:
Sanneke van Asselen / Deltares and NOBV data support.

Subject:
Request for NOBV Zegveld extensometer and groundwater time series for peat poroelastic storage research

## Message

For the SWAP5 soil-water model we are investigating whether reversible
poroelastic deformation of saturated peat can be used to derive a physically
based layer-specific skeleton specific-storage parameter.

The immediate target is not long-term subsidence. We want to test the
short-timescale relation between groundwater-head change and reversible
differential deformation of saturated peat layers.

The 2025 HESS paper by van Asselen et al. and the earlier NOBV reporting indicate
that Zegveld parcel 16 is particularly suitable, including the saturated peat
intervals around 1.20-4.49 m below surface in the reference plot and
approximately 1.21-4.71 m in the pressure-drain plot.

The 2026 EGU contribution by van Asselen and Erkens
("Unravelling shallow subsurface deformation processes leading to land
subsidence in organic-rich coastal plains", EGU26-1131) is especially relevant
because it explicitly uses multiyear extensometer time series at multiple
subsurface levels to separate reversible and irreversible deformation of
different soil intervals.

Could you provide, or provide access to, the following for Zegveld parcel 16,
preferably for the complete available 2020-2023 period and, if available, the
extended series used in the 2026 analysis:

- timestamped extensometer displacement/elevation for all anchor levels;
- exact anchor depths/elevations and reference-anchor identity;
- timestamped local phreatic groundwater levels at the wells corresponding to
  the extensometer locations;
- deeper hydraulic-head observations if available;
- sensor quality flags, resets, maintenance/recalibration information and gaps;
- units and sign conventions;
- measurement resolution/precision;
- the lithological/profile metadata used to assign the anchor-bounded layers;
- if available, the interval definitions, quality-control decisions or
  reversible/irreversible decomposition used for the 2026 EGU analysis.

Hourly or the highest available temporal resolution is preferred. Raw or
minimally processed data are preferable to plotted or aggregated values.

The intended analysis uses differential displacement between adjacent anchors
to derive layer strain and tests whether, for fully saturated reversible cycles,

`Ss_skeleton ~= -d(epsilon_z)/dH`.

We will keep reversible poroelastic response separate from oxidation, shrinkage,
irreversible consolidation and creep. A first analysis will be restricted to
identifiability and will not assume in advance that peat can be represented by
one static scalar Ss.

If direct database/Grafana access is the preferred route, access instructions
for the relevant NOBV Level0/Level1 data would also be very helpful.

Relevant references:
- van Asselen et al. (2025), Hydrology and Earth System Sciences 29,
  1865-1894, https://doi.org/10.5194/hess-29-1865-2025;
- van Asselen & Erkens (2026), EGU26-1131,
  https://doi.org/10.5194/egusphere-egu26-1131.
