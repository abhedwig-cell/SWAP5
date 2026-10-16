# MC-SOL01 actual changing pond application

Status: canonically admitted bounded successor PR1258 at
`6353f109d00763fcb4f533f2f764c8eb50db99d5` to bounded PR1257, baseline canonical
`93c4cb62f0a6c0dbe8bf47b6eeeef0752c39d694`. Implementation and qualification
status live in `integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json`.

The optional `fmr_pond_input_forcing_t` supplies gross rain and irrigation rates
(cm/day), each finite in [0, 5e5]. Its absence preserves the existing fixed-flux
application. Its presence requires zero prescribed top flux and excludes snow,
Black/Boesten evaporation, Rutter, RFM, macropores and fixed-weir surface water.
Only the existing BASE physical state is admitted by this new route. No evaporation, runoff, melt or runon may be hidden in the supplied rates.

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

## Explicit temporal comparison for the new route

The admitted temporal-history indicator supports prescribed flux, so it cannot
certify a changing dynamic head boundary. The old BASE identity-only full/half
comparison also cannot certify evolving pond storage. Neither guard is relaxed.
The new input option therefore requires BASE state, default MvG with SWKIMPL=0,
Reference solver and the existing external full/half controller. Its explicit
comparison is the maximum absolute difference (cm) of all pressure heads, pond
depth and groundwater level between independently computed full and two-half
candidates. Reject nonfinite or inconsistent state shapes. The caller supplies
the existing numerical temporal tolerance in cm; no production tolerance or
fallback is substituted. The qualification fixture selects 1e-6 cm and retains
the independent 1e-10 cm water gate. This contract is new only for the optional
pond-input route. Existing fixed-input certificate and identity semantics remain
byte-for-byte unchanged after removing the declared inserted islands.


## Stable-candidate evidence

The source-bound O0/O2 execution passes42 new native programs and12 incumbent
programs, including unchanged fixed/dry1257 and original surface endpoints and
native restart bytes. New23-case comparison leaf passes separately at O0/O2;
real zero-tolerance rejection proves the temporal comparison remains operative.
Each written physical scenario executes8 forcing negatives,21 last-carrier/source
negatives per interval, rejection after completed water, smaller retry, replay,
independent literal B1.11 and whole water/chemical balances. Fresh processes
continue both actual pond depth and matrix surface mass without a new codec.
The28 evidence/source controls and both actual FCI owner entrypoints pass.
Source/strict docs pass. Measured full closure328.698s includes220.562s provider
compile,18.766s preservation driver compile,8.180s new native and78.360s incumbent
native; categories are retained separately in the raw event manifest.

Actual fixtures use low-conductivity default MvG and -1 cm initial head to
exercise persistent rather than immediately drained storage. Zero-input wet
pond drains; gross rain/irrigation fills it; dry deposition survives a zero-water
interval and remobilizes under explicit rain. This is not arbitrary dynamic-pond
or high-flux-front qualification. Earlier failed/censored attempts are retained
and never counted PASS. Generic optional surface/heat/N combinations remain
outside this qualified joint-application contract. Canonical admission is a
separate status receipt; master dispositions are not promoted by these tests.
