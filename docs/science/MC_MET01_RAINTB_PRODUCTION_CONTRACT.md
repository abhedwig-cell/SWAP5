# MC-MET01: typed RAINTB and guarded authentic production

Status: delegated bounded application decision before implementation; numerical
qualification and canonical admission pending. Baseline `c545077ab2d2839007a4ac202f7896575d0ad9ba`.
Owning roles: existing REGIE/PPA/RT with MC-MET01; MC-CROP01 contracts remain fixed.
User delegated implementation of the canonical pilot on 12 October 2026.

The optional `file_weather_swrain=1` profile accepts a validated immutable typed
RAINTB configuration (strictly increasing day-of-year knots, finite positive
cm/day intensities, constant endpoint extrapolation). Fully populated tables
only; historical partly filled sentinels and file grammar are not this input API.
Default mode0 remains the existing uniform-day profile. Mode1 is root-free only,
with the existing AIR/no-snow/default-MVG bottom7 weather envelope.

Authenticated B1.11 MOD_meteo lines643-644/657/677-686/694-696 determine mm→cm,
strict rain>1e-8mm, AFGEN day-of-year and pulse duration/rate. AFGEN arithmetic
and endpoint order are retained for valid finite full tables. Tiny rain at or
below threshold supplies zero, as the source event schedule does. Invalid table,
unrepresentable positive pulse endpoint or invalid intervals fail closed.

The existing guarded weather entry resolves pulse segments before calling its
incumbent physical interval body. Each segment has a positive interval entirely
within the authenticated day and one constant rain rate. A request spanning the
pulse boundary executes at most two segments; it returns one column-result per
attempted segment in chronological order in this opt-in profile. This additive
result-array meaning applies only to mode1. A failure of the second segment
retains the previously completed physical/weather prefix; the failed segment
publishes neither internally accepted partial physics nor accepted weather-window
progress. Overall status reports failure and segment results remain distinguishable.
Default mode0 output/result shape stays identical.

No externally set private active flag, second transaction/weather owner, new
time reset, zero interval, fabricated crop receipt or precipitation scalar that
pretends to be authentic input is permitted. Segment receipt and accepted-window
publication use the existing F-KT and weather-window owners. The derived schedule
has no independent mutable progress state; committed soil time plus immutable
record/table reconstruct the next segment. Existing joint continuation retains
the complete table in its configuration. Mode1 restore additionally requires an
expected table that matches all validated knots/values before any owner publishes;
wrong/missing table fails without initializing crop or application.

Qualification: independently compiled literal source/AFGEN oracle including
threshold, leap calendar, knots, capped pulse and invalid inputs; actual authentic
wet/dry/wet production, pulse/off/next-day, O0/O2 full vectors and restart inside
and at pulse boundaries; duplicate, foreign record, changed table, failed interval
and retained-prefix retry. Preserve incumbent uniform/crop/root/thermal trajectories,
complete affected highest frost and current Full Richards/F-CI owner gates with
unchanged assertions/tolerances. A new exact-source successor may recognize only
the independently qualified precise postimage; every unknown mutation fails closed.

Typed rainfall distribution within this bounded application is the admission
claim; parser, rooted rainfall, interception, detailed weather, broad seasonal
accuracy, external disk codec and full MC-MET01 remain outside it. Master disposition
can close only the exact claim it requires; otherwise record bounded reachability
and retain ACTIVE. All raw failures and immutable qualification lineage remain.
