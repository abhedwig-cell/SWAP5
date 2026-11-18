# Direct soil irrigation age input and complete restart

**Current / canonically admitted through PR1727, actual merge5014520ed.** Baseline is actual canonical
e3cb491d15b9d079062285c397cfba552ab0a86d (PR1725/1726). Production26724ce75
implements explicit `--age-direct-soil-source`; default is false and selecting
it together with `--age-irrigation-source` is refused. Historical functional
closure remains PARTIAL, whole science NOT_QUALIFIED and fixed RC3 is unchanged.

The actual source merge has the exact e3cb491d1/31a931a79 parents and complete
qualified27401b01tree. Its detached registered owner passes; the actual
postimage/result is recorded by
`integration/f-ci/nomacro-complete01/DIRECT_SOIL_AGE_MERGE_RECEIPT.json`.

## Original defect and explicit correction

Original fixed IRTYPE2 produces qssdi per compartment but does not assign CIRR;
the original age equation has no direct qssdi age input. Actual32original
executions per platform on O0/O2 prove that point and interval IRCONC0/20day
inputs produce identical profiles,2.4cm actual water and zero CIRR. Nonmutating
probes reproduce original profiles exactly. A scoped original correction sets
current CIRR and adds qssdi*age*dtsolu after each transport microstep. It supplies
48cm day, changes positive-age profiles and exactly preserves zero-age profiles.
Plain corrected runs and diagnostic runs agree. These are bounded source
counterexamples; whole original age-profile equivalence remains unqualified.

`mod_direct_soil_age_substep` composes the literal accepted B111 soil provider
with compartment input qssdi(cm/day)*IRCONC(days)*dtsolu(day), in cm day. The
explicit policy transports committed age first, then adds direct input at the
end of each microstep. Incoming age participates in subsequent transport
microsteps. The real four-object driver passes O0/O2 conservation, rejection,
zero-source exactness and temporal refinement. Its actual two-cell errors
decrease0.0041117â†’0.0020226â†’0.0010032 as the microstep is halved. Failure returns
committed state; source, transport and shape errors are refused. There is no
clipping, artificial age production, pond handoff or chemical mass conversion.

## State and guarded process scope

The twelve-field accepted age protocol retains the existing eleven fields and
appends cumulative direct soil input. Soil and combined age balances subtract
that actual external input; the pond ledger remains unchanged. Age tolerance is
8192*epsilon*max(1,actual age inventory,actual age fluxes), with cm day units.
Water and chemical guards remain1e-10cm and1e-10mg/cm2. Original static
Ageirr/Agepre/Agedrain parameters, all four physical age providers and all old
calendar/output/irrigation helpers remain literal.

Six distinct codecs S5DI0002/3/4/5, S5DIO001 and S5DIH001 retain the complete
existing physical, irrigation, age, calendar and output owners. After the
existing56byte current-source domain they append a24byte direct input owner:
paired version/node headers and cumulative direct age amount. Existing private
irrigation state owns the current event; reconstructed IFND and the complete
active input table/cursor/CIRR checks remain inherited. The new counter is
transactional and serialized. Old checkpoint formats are not converted or
adopted into the new policy.

The explicit scope is analytical no-macro SWSOLU2/SWIRFIX1/SWDRA1, incoming
ages0..1000days, all four fixed forms, original adaptive-day-seed time policy,
the six admitted calendar/output families and both scanning initializations.
Snow, frost, aquifer, detailed weather and other unqualified domains remain
excluded. A missing native field in the first regular-calendar prototype was
correctly refused by the twelve-field ledger; only the explicit adapter now
extends that actual observer. Failed v1 runs remain retained and are not rebound.

## Actual qualification and preservation

Windows and Ubuntu each execute17short profiles per optimization and22full1096day trajectories
(11per optimization),158full cold windows and106short cold windows. Actual
48/72cm day varying gifts, year/season/last-gift windows, all six typed families,
zero/1000day and inline inputs pass. Format0/3have exactly equal1096physical
rows and seven complete native endpoints per optimization. Each platform has
304native refusals,80fabricated-ledger refusals and16active first/second-gift
discard/replay/accept/recovery contexts. Independent public commands and complete
cold restart pass for NP3, hysteresis/binary and per-step/monthly profiles;
six real reader and nine descriptor refusals pass on each platform. Windows
also proves first-day48cm day and true terminal-day cumulative120cm day with
six exact cold windows.

Fresh Windows preservation covers47contexts:16prior current-age families,
20ordinary/hysteresis routes, eight young fixed forms and three named profiles.
Complete old project/input metadata, actual emitted source/provider closure,
physical rows, user files and native payloads remain exact. Ubuntu separately
preserves six current-age families and four older water/CDE/age/output routes.
Only actual19character Generated-at wall clocks are normalized for file
comparison. The actual immutable young-water archive independently matches
ten zero-source physical days and complete prior native payloads at days2/4/8
on O0/O2, after comparison-only projection of the new zero protocol fields,
codec and80byte owners. No checkpoint is rebound.

Authority is `integration/f-ci/nomacro-complete01/DIRECT_SOIL_AGE_QUALIFICATION.json`,
sealed ate4a31277c, with seven immutable raw ZIPs and293actual report/build
bindings. Ubuntu runs44246149974and44247509054are terminal SUCCESS; downloaded
artifact bytes and every member hash are verified. The registered owner
recomputes accepted age/water balances and actual native/output comparisons on
44full periods. All3005proof corruptions and an actual dirty/committed ignored
source mutation are refused. Existing admission bodies remain literal under
one successor hook; prior proof is validated on its actual pinned source image
with unchanged raw archives, alongside fresh current-route preservation.

Affected invariants:3,4,7,13,21,23,30. This is a bounded source/state/output
admission, not complete historical migration or a new named release.
