# B1.11 crop source resolution, 6 October 2026

Reviewed canonical baseline: `78acf56f931763d2e1d4924b3dea0742f231d2e8`.
This is source/implementation adjudication, not a new crop admission.

## Correcting the annual-crop comparison

The previous master entry compared B1.11 AMAXTB only with the newer WOFOST81
leaf-N assimilation route. That comparison was incomplete. The separate classic
production route exists: `mod_wofost_prepare_assimilation` evaluates AMAXTB at DVS,
multiplies by temperature and supplied CO2 factors, and feeds the two-phase crop
window and `mod_fmr_wofost_crop_transaction`. The common rate finalizer implements
IDSL0 and IDSL1, including bounded daylength reduction before anthesis.

The existing PP03 current-contract wrapper was rerun locally. F-WOF38 atomic
crop transaction and F-WOF39 receipt-gated event retirement pass at O0/O2, with
output identity. The wrapper changes only historical fixture/build compatibility;
the original scientific assertions are retained. F-CI89 explicitly preserves this
classic runtime while separately admitting WOFOST81. This eliminates a claimed
absence of classic AMAXTB code. It does not qualify every B1.11 annual-crop path:
the classic implementation documents a B1.10 reference, the source carries both
potential and actual crop trajectories, and the independently qualified PP01
full-season donor is the separate WOFOST81 donor. The remaining annual/IDSL1
question is source-envelope/admission evidence, not implementation of AMAXTB.

## Confirmed missing owners and resolvers

| Capability | B1.11 execution | Production boundary and required successor |
| --- | --- | --- |
| SW431-CROP-SOY | `wofost.f90` functions `rfmgtemp` (1950 onward) and `rfmgphotop` (1981 onward): nonlinear optimum-temperature response, short-day inhibition, maturity-group or explicit photoperiod thresholds | The current finalizer supplies thermal-sum development and linear long-day IDSL1, not this soybean dispatcher. Add typed soybean parameters and independently qualify both threshold modes and the vegetative photoperiod switch. |
| SW431-CROP-GRASS | `wofost.f90` management_event (2078 onward), trigger_management_event and mowing_event: biomass removal, leaf-cohort removal/reset, harvest/loss accounting, cutting/grazing counters and regrowth delay | Current crop owner has biomass, DVS, thermal sum, anthesis and minimum-temperature history, but no agro-management owner or operators. Event receipt retirement is not mowing or grazing. Qualify management selectors separately, retaining one biomass owner. Inspect source loss initialization before migration; do not copy an undefined temporary. |
| SW431-CROP-SOW | `MOD_cropdevelopment.f90` preparation (453 onward), sowing (538 onward), germination (647 onward): pressure-head delay, soil-temperature threshold and accumulated germination progress | Current inactive crop explicitly forbids biomass/continuation state and has no preparation-delay, sowing-delay or germination-progress state. These are application physics, not file cursors. Split preparation, sowing, thermal germination and moisture-modified germination in the implementation contract. |
| SW431-CROP-ROOTGROW-DVS | `MOD_cropdevelopment.f90` 1874 onward: min(AFGEN(RDTB,DVS),RDM), used as actual and potential depth | A supplied cumulative root-fraction vector is a consumer input, not this typed depth resolver. Add the bounded table/depth mapping, then qualify its root-fraction integration. |
| SW431-CROP-ROOTGROW-BIOMASS | `MOD_cropdevelopment.f90` 1887 onward: min(AFGEN(RLWTB,WRTpot),RDM), with actual biomass branch later | Current crop biomass is available but no RLWTB/depth resolver is bound. Keep actual and potential biomass ownership explicit and test interpolation/endpoints and maximum-depth clipping. |

These five entries now have demonstrated missing owners/resolvers, rather than
the generic phrase that Spring Barley qualification does not cover them. No new
physics implementation or rejection decision is implied.

## Remaining crop distinctions

CO2 factor multiplication exists in classic and WOFOST81 assimilation. F-WOF43A
also implements a stateless transpiration-factor table, but explicitly does not
own calendar-year CO2 selection and its historical qualification is not a blanket
scientific admission. Annual forcing selection and the combined crop/ET envelope
must be traced separately. No absence of factor multiplication is asserted.

Actual RELMF multiplication exists. Source `SWPOTRELMF=2` additionally multiplies
the *potential* trajectory. A single actual owner and an external potential input
do not establish that dual-trajectory option. Crop rotation likewise includes
start/end and harvest state, not merely the already implemented consumption of
a daily event token. These entries remain explicit source/ownership reviews.
