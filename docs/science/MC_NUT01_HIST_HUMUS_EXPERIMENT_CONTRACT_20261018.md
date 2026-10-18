# Historical optional humus-rate experiment

Status: qualified bounded PR1316 candidate. Canonical admission is recorded in the work-unit status; full HIST completion remains false. Baseline canonical is
`01a053f93f9c6548278df503a4cfea5424c84fce` (PR1314). Work unit remains
MC-NUT01-HIST-COMPLETE. This extension uses the existing reactive owner and
organic turnover kernel; it adds no pool, second reaction implementation or solver.

Pinned management_soil lines242..246 defaults RateconHum_exp to-1. If present,
it reads0..100 per year, divides by365.2425 and requires tstartHumexp via RDSTIM.
Pinned wofost_soil_rateconstants lines25..29 selects the experimental reference
rate only if its converted daily value is strictly greater than1e-6 and current
soil day is at or after the experiment start. The normal temperature/moisture
factor then applies. Zero and small positive rates do not disable humus turnover;
they retain the original reference rate, exactly as the source specifies.

Append default-absent immutable daily rate/start-day fields to existing reactive
parameters. Select the original reference rate before the existing environmental
factor; send that parameter to the existing organic kernel. No new dynamic state
is needed. Parameter identity includes any explicitly supplied experiment,
including zero/inactive values, in an appended marker block. Absent experiments
preserve every old parameter/native byte. Existing restart adapters compare full
immutable vectors and must reject different rates or start dates atomically.

The native named parser uses the existing amendment date parser for daily dates;
TTUTIL day1 and SWAP5 day0 map explicitly. The two fields must be paired. Missing,
duplicate, malformed or contradictory input rejects with the original physical
source line and no partial owner/calendar. Modern export does not acquire native
fields silently. Fractional dates remain outside the daily production contract.
Optional flCropExt=false may be accepted with the original default semantics;
true extended diagnostic output remains unsupported unless separately implemented.

Selected qualification: small fresh O0/O2 original-rateconstant/organic/transport
comparisons before/on/after the start, above/below/equal strict activation threshold,
zero/default rates and restart across the switch. Native positive/negative input
matrix and unmodified TTUTIL date/rate interpretation. Production730-day crop,
harvest/fallow/successor composition must cross a configured start and resume in
fresh processes on both sides; preserve all old profiles and owning retained,
thermal and TCS6 evidence on the changed dependency surface. No mastercoverage
or full-HIST claim follows from this contract. RossFast stays outside scope.

Affected invariants are1..4,7,9,11,13,21..23,25,26,28..30. The existing water/N
mass gates, rollback, crop ownership and native schemas remain hard contracts.

## Original caller-clock reconciliation

The original swap caller executes TimeControl(3) before SoilManagement(2), then
SoilManagement(4). TimeControl increments t1900 by dt; SoilManagement(2) assigns
t1900Soil=t1900. The experiment therefore tests the interval endpoint, not its
start. In SWAP5 daily coordinates the exact source predicate is t1>=start_day.
Because TTUTIL dates identify calendar midnights, this can activate on the day
preceding the nominal input date. This historical ordering is preserved explicitly,
without silently applying a corrected calendar-start interpretation. A separate
executable witness must bind the original caller/timecontrol source and prove
the end-of-day selection. Initial t0-based development evidence is diagnostic
only and cannot qualify this contract. The730-day fixture uses input1901-12-31,
so the original endpoint predicate switches on the interval starting at day365.

## Qualified surface-age coexistence

Canonical advanced to d4912b3c37461ad918f37c53b236fa1d62478de6 via PR1309.
Its thirty surface-age postimages and physical evidence remain authoritative.
Neither its compiled physical inputs nor the compiled NUT closure overlap the
other workstream's changed physics. The shared HIST dispatch and its new age
back-reference are explicitly reconciled; no surface-age process is changed.

The new NUT guard uses that admitted canonical as its source-delta baseline,
requires an exact registered postimage set, and validates fresh NUT evidence.
It pins the unchanged age status record and every original age postimage, with
only the two registered dispatch files owned by this new qualified postimage.
It revalidates original age physical evidence against every current compiled
input. The age guard may delegate source-delta checking to that exact registered
NUT guard; NUT calls only age evidence validation, so no recursion or broad
foreign-delta exemption is introduced. The old age physics qualification is
inherited solely because all of its actual execution dependencies are unchanged.
Full F-CI is not selected merely for the advanced branch head.
