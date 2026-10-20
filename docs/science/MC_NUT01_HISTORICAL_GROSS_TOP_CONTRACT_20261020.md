# Historical gross atmospheric N: owner decision and implementation contract

Status: implementation candidate, not admitted. Baseline canonical
`d443dced3313e2602fdea4cbd1a6cb566f53fb0e`.

On20 October2026 the programme owner selected option1: preserve historical
gross atmospheric N loading, original process order and the original aggregate
ponding convention. This resolves the previously open reference choice. It does
not authorize a corrected surface NH4/NO3 store or new runoff-mixing equations.

Original management_soil lines400..402 supplies
`0.01*(igrai+isnrai+igsnow+igird-iintc+irunon-iruno)/outper` in m/day to
Wofost_SoilWaterN. Soil evaporation is separate. Original analytical transport
uses that top term in its production/input coefficient while independently
using initial/final water contents. Thus rain4mm and evaporation4mm must still
load atmospheric N even though net soil-water input is zero.

The existing mineral/reactive/crop/calendar owners receive an optional
`historical_top_water` argument, in m/day, containing that source aggregate.
It is not a water source for Richards and is not substituted into the hard
water closure. The accepted net carrier remains the only water authority.
In the existing analytical solution and external-input receipt only, the
explicit historical argument replaces positive net infiltration. Organic
reactions, source ordering, source crop demand and all ownership are unchanged.
Absent the argument, existing admitted endpoints must remain byte-identical.

This first executable candidate covers finite nonnegative historical aggregate
rates0..100m/day, the same bounded numeric scale as the existing mineral carrier.
Negative aggregates, including any runoff-from-prior-pond case producing one,
remain rejected pending direct source/positivity qualification. No claim of a
new physical pond-N balance is allowed. The accepted aggregate convention is
preserved rather than inferred from infiltration. Whole HIST remains open for
this outstanding domain, automatic original atmosphere producer binding and
the previously recorded native input/output/original-model envelope.

The joint runtime requires explicit `atmospheric_n_surface` opt-in and rejects
invalid historical input before a water trial. A new optional forcing value
does not add committed state, cumulative inventory or a restart schema. Source
identity continues through existing immutable c_top and native parameter vectors.
Historical gross forcing must be supplied again for each resumed interval, like
weather; rejected candidates publish neither water nor N.

Affected invariants are the existing atmospheric contract's1..4,7,9,11,13,
21..23,25,26,28..30. MC-NUT01 owns this extension; shared solver, matrix, age,
surface stores and MC-SOL01 production are read-only. No RossFast extension.

Selected qualification: four-provider mineral O0/O2 with original unmodified
watern,18 combinations of gross input, water endpoint and sorption, invalid
input rollback and opaque continuation. Actual323-provider Reference
Richards/WOFOST81/Soil-N O0/O2 executes all original default/source124/three730
profiles and one new730-day gross profile. The new profile retains humus,
two crops, harvest/fallow/successor, chemical and actual hydraulic rejected
trials, and six fresh-process transition continuations per optimization.
Water/N tolerances and the original drying-stress failure are unchanged.

Expected full actual gate cost900seconds. Existing owning retained/thermal/TCS6
and historical evidence validators remain admission requirements, not inferred
PASS from a small process test. Changed production providers must be bound to
fresh execution and immutable predecessor endpoints before any canonical merge.
Full moving F-CI is not automatically selected by this forcing-only owner seam;
check actual shared-semantic impacts before selecting it. No tolerance, native
assertion or corruption control may be weakened to accommodate new evidence.
