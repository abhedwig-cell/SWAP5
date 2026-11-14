# H original weather/reference ET and subdaily precipitation

Own branch08 from canonical3aa554460 (G PR1681 exact verified tree2e604c91b).
FrozenRC111529865e. Relevant source authority MOD_meteo.f90, timecontrol.f90,
MOD_cropdevelopment.f90 and original Hupsel SWP/meteo bytes. Invariants2/3/7/13/
21/23/26/27/29/30; no Richards, codec or Fortran equation changes planned.

Original daily dataset already includes reference ET and wet-duration columns.
ReadMeteo supports SWETR0/1, SWDIVIDE0/1, soil factor SWCFBS0/1, SWRAIN0..3,
and SWMETDETAIL0/1. Original constraints: prescribed ET1 needs daily weather
and SWDIVIDE0. Detailed meteorology requires ET0, rain0, no snow. Referenced
crops cannot use interception1/2 with detailed meteo or rain3; unused files do
not activate processes. Preserve those constraints before build/output, never
silently switch physical options. Further numeric/data validation remains in
the original reader, not reimplemented.

Contract: expose those original process choices through experimental adapter.
No new public state API or physics implementation. Eight derived Hupsel cases:
PM factor partition; PM partition+soil factor; measured reference ET; reference
ET+soil factor; original mean rainfall-intensity table; measured rain duration;
detailed rain file;24-record daily detailed meteorology. Detailed cases explicitly
select interception0 for all future referenced crops. Detailed rain file defines
three interval-end records per day, preserving daily amount with fractions
0/0.8/0.2 at0.25/0.5/1.0. Detailed meteo derives24 records from the same daily
data: explicit diurnal temperature/radiation and uniform hourly rainfall.
These are synthetic temporal redistributions, not independent historical or
unchanged daily-weather reference claims. Preserve same daily totals; pin all
new input bytes. Original whole MOD_meteo/process order remains the owner.

Qualification: full1096 days per selected case, actual touched-unit/controller
O0/O2, exact native2/365/530 and complete endpoints; balance, independent origins,
external discard/replay/disk recovery and mass/input refusals. Original executable
uses the exact same derived physical files; only CSV reporting compatibility
may differ. Whole science/energy not promoted. Hourly state continuity must
actually pass; if not, keep family refused pending a larger original module
state strategy, not speculative cache tweaks. No old capsule rebinding.

Dispatch changes only; full original model closure is justified by calendar,
TTUTIL, atmospheric/crop/thermal and native-state ownership. No copied weather
formula or mock substitutes for that production composition. Runtime/source
of prior qualified options is unchanged; prove old descriptors unchanged.
Expected own-runner cap25minutes. Expensive execution selected for uncovered
original temporal forcing/state risk, not a platform/performance campaign.

FirstH43593959340 source4d3e41c8a: factor-partition completes full1096, actual
O0/O2 native2/365/530 and all transactions/reference gates. factor-partition-soil
completes1096 but cold365->366 differs water0.006376066972421768cm, Hmax
0.14686493507930454cm; native367 differs. Both balances pass, so do not call it
restart-qualified or relax exact state. Original SWCFBS1 chooses a different
Penman soil branch depending on original plant_interface swcf/canopy fields.
Read-only discriminator will trace complete original plant/ET interface at
accepted365 versus cold365, reproducing original warm/cold rows without accepted
publication or origin rebinding. No public state repair yet. Then preserve a
larger original component state if proven, not blind individual-cache trials.
Select only other still-uncovered non-soil-factor variants while diagnosing;
retain first completed case without unnecessary re-execution. H remains draft.

Read-only diagnostic43595033501 e910240ee SUCCESS reproduces both original
warm/cold366 physical rows exactly, unchanged sealed365 origin and no accepted
publication. At accepted365 swcf=1, CO2=360 and all three CO2 factors=1; cold
initialization has swcf=0, CO2/factors=0. Other traced original plant ET fields
and icrop/emergence agree. SWCFBS1 makes the missing crop-factor selector
physically active in Penman soil evaporation even before emergence. This is
not mass tolerance or numerical rounding; missing original interface memory.

Contract before state integration: preserve the complete original plant/ET
interface block swcf,cf,ch,albedo,rsc,rsw,kdif,kdir,vcover,co2,fco2amax,fco2eff,
fco2tra, for experimental activeSWCFBS1 only. Read/write directly in the original
plant_interface module, restore after Solute1 initialization and before original
Meteo2/croprotation2 dynamics. Output initialization has no assignments to these
fields (source audit). No after-crop overwrite, no selector/physics reset or cache
reconstruction. Input-bound icrop and emergence already have distinct correct
owners and are not duplicated. Use distinct ET auxiliary formats per chemical/
history mode; append100byte block, strict finite/domain/truncation/format checks,
no extra state/source changes when inactive. Existing methods/codecs stay exact.
Full two SWCFBS1 cases plus actual O0/O2 decoder attacks and old8 default source/
external preservation are selected. Remaining non-soil-factor weather variants
run separately on e910240ee; no duplicate first completed factor-partition.

Accepted plant/ET block now implemented only for experimentalSWCFBS1. It is
restored directly after Solute1/native restoration, before original daily meteo/
crop dynamics, not after crop update. The complete original module interface
contains one selector and12real fields (100bytes), with strict read AND write
finite/domain validation. Distinct ET chemical/water/history formats; inactive
sources/old codecs unchanged. Local real production-code O0/O2 driver compiles,
roundtrips100bytes exactly and rejects6actual corrupt read/write modes each.
Six old managed/history/no-management codec variants are byte-identical against
canonical3aa554460; eight new header combinations render (not full combination
qualification). Full new corpus adds water-only soil-factor to qualify chemistry-
independent state,9 requested full configurations. Whole native corruption tests
select new ET modes in addition to direct small-driver attacks.

Remaining43595046093 stops at original future cropfactor error on day523,522
accepted: original prescribed ET1 requires SWCF1 in every future crop; potato
originalSWCF2 is incompatible. Preserve that original refusal; valid derived
reference-ET fixtures now explicitly select1 using their existing original CFTB.
Preflight enforces every referenced crop, no implicit runtime change. This is an
input compatibility correction, not a numerical repair. New full9 and default8
source/external preservation are next; no H qualification yet. Existing Fortran
physical laws/solver/time policy/tolerances remain unchanged.
