# Daily amendment calendar contract, 15 October 2026

MC-NUT01-AMENDMENT-CALENDAR, canonical baseline
`e22a677146ef49d14bd6dd6e72b78f60e340bcab`.

## Owned boundary

Add an immutable typed forcing calendar and additive real crop/soil and Richards
application wrappers. Read-only owners: current material chemistry, existing
soil/crop owner, daily environment, Richards carrier and complete restart.
No existing physical formula, owner state, event cursor, parameter identity,
restart schema, WOFOST81 fixation or solver change. Calendar selection is pure;
the existing accepted daily clock prevents replay and skipped execution. Caller
resupplies the same external calendar after restart, as with weather forcing.

Calendar inputs map original `smedate`, material-table index `MatNum`,
`Dosagekgha` and event `VolatFraction`. Convert dosage exactly by1e-4 as the
immutable management source does. End-of-day trigger is the exact original
`abs(TimeAmend(isme)+1.d0-t1900)<1.d-3`. Apply the selected amendment before
the original daily reaction/crop process. No application day is an empty batch.
Material definition age/fractions remain owned by the original material builder;
calendar validation does not replace its physical domain checks.

## Deliberate historical-compatible input envelope

Source SHA256 `0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b`
rejects unsorted dates and groups with strict `<0.d-3`. Sorted equal dates are
therefore not grouped. Donor1117 sorts records and groups near dates, which is
not this immutable authority and is not imported here.

Accept only strictly increasing integer daily source dates within an explicit
integer simulation interval; at most one application per day. Reject duplicate,
near-date/fractional and unsorted calendars explicitly. This selects the
unambiguous original domain without a new reference correction. Do not silently
sort, merge, clip, skip a past first event or claim general donor equivalence.
Maximum3660 event rows and64 material definitions; dosage0..500000kg/ha and
volatilization0..1. Definitions carry age/fractions only; event amount and
volatilization must be zero in definitions to avoid ignored input fields.

The profile is opt-in typed daily amendment forcing, not a legacy .snm parser,
default activation, multiple same-day applications, crop-residue debit/return,
harvest/reset or accepted heat coupling. PR1239 separately owns senescence and
pending state; do not modify/import its unfinished owner. PR1234 owns surface
solute input. Aquifer stays rejected. No full capability/count promotion.

## Four-level selection before execution

1/2: tiny real calendar closure and original extracted date/check/conversion/
group/trigger source at O0/O2; material-index association, units, empty schedule,
invalid ranges/NaN/overflow, source trigger boundaries and constructor nonmutation.
Small real crop/soil day compares selected calendar and explicit material route,
literal eight-pool/mineral/supply outcomes, no-event day, invalid calendar/day,
retry/replay and atomic failure. Expected3 and43/44 providers, under25s build.

3: actual Richards composition with calendar event days/no-event day and explicit
daily environment, real WOFOST81 and original literal chemistry/rate/water/uptake
oracle; whole-N, failed/retried day, immutable forcing, replay, opaque/native
fresh-process continuation and original19 corrupt payload controls. One fresh
shared provider build per O0/O2, every native assertion fresh; expected263
providers and250s compile/link/native. Original profile endpoints must remain
byte-identical. Preserve exact input/flags/compile/link/native/raw identities.

4: stable local full moving OFF selected after source/owner guards, because the
new forcing/calendar caller enters actual production composition. Expected
1800s under AGENTS four-level stable admission and protocol rule8. Full category
split and physics-only costs UNKNOWN. Highest low-air NOT_SELECTED_POLICY.
No hosted dispatch; inspect existing automatic checks only. Reuse unaffected
evidence only with exact dependency binding. Reconcile PR1239/1234 and live
canonical before admission. One work PR; checkpoint is not a stopping point.
