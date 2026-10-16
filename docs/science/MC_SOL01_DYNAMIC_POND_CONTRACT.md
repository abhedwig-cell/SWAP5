# MC-SOL01 actual changing pond application

Status: proposed successor to bounded PR1257, baseline canonical
`93c4cb62f0a6c0dbe8bf47b6eeeef0752c39d694`. Implementation and qualification
status live in `integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json`.

The optional `fmr_pond_input_forcing_t` supplies gross rain and irrigation rates
(cm/day), each finite in [0, 5e5]. Its absence preserves the existing fixed-flux
application. Its presence requires zero prescribed top flux and excludes snow,
Black/Boesten evaporation, Rutter, RFM, macropores and fixed-weir surface water.
Only existing BASE and temporal-history physical states are admitted by this
route. No evaporation, runoff, melt or runon may be hidden in the supplied rates.

For every physical sibling, retry and substep, bind the existing dynamic-top
provider from that trial's actual committed pond depth and duration. Zero loss
rates and a 1e6 cm pond bound select its existing no-runoff profile. Exceeding
that bound fails closed in the provider; there is no clamping or lost water.
Numerical equations, convergence tolerances and timestep policies are unchanged.
The accepted trace records actual begin/end depth and top flux. The application
requires exact equality of chemical rain/irrigation rates and the water forcing.
The existing chemical consumer independently requires, for every substep,
`depth_end-depth_begin=(rain+irrigation+qtop)*dt` within 1e-10 cm.

Water depth remains in the admitted hydraulic state. Chemical surface mass stays
solely in the admitted matrix companion. The existing PR1257 infiltration/mixing,
retained dry solute, explicit dry deposition and joint publication rules remain
unchanged. Use existing PR1256 opt-in V2 native restart; introduce no codec or
committed sidecar. Failed water, chemical or commit stages publish neither owner.
Aquifer remains excluded. Surface evaporation/runoff chemistry, surface age and
simultaneous N companions remain separately unqualified.

Select focused real O0/O2 application tests with draining and accumulating pond
storage, dry deposition and rewetting, literal B1.11 source comparisons, water and
whole soil-plus-surface mass, chemical rejection after successful water and smaller
retry, replay, invalid forcing and fresh-process continuation. Run original1257
fixed/dry and original surface programs against the same compiled providers.
Keep source-bound evidence and guard controls; no unrelated solver qualification
is selected merely because the dynamic provider receives valid inputs.
