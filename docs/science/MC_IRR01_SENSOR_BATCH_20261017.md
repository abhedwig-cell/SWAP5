# MC-IRR01 TCS7/TCS8/SSDI coherent sensor batch

## Authority and complete-row contract

This continues [issue1271](https://github.com/abhedwig-cell/SWAP5/issues/1271)
after the four full TCS2/TCS3/TCS4/DCS1 admissions in PR1272. Existing workstream
MC-IRR01 owns [PR1273](https://github.com/abhedwig-cell/SWAP5/pull/1273), branch
`work/mc-irr01-sensor-batch-1271-20261017`, baseline
`a8d65af4c1ab4cb53d1cd9609d21062752b13026`. Recovery is the existing
`MC_IRR01_STATUS.json` field `sensor_batch_1271_20261017`.

The three complete existing rows are TCS7 pressure-head sensor, TCS8 water-content
sensor and SSDI single-node/depth-interval distribution. Original restrictions
were historical parameter/season activation, broader accepted management/spatial
composition and native weather continuation. These receive source/real physical
qualification here; no bounded replacement row is created. Independent
HYD/POWER, crop and SALTEXCESS compositions retain their own admission conditions,
as for admitted root selectors, AVAIL and LIMIT. Generic legacy disk parsing and
uninitialized raw AFGEN table tails are not newly claimed. Typed sensor/node and
contiguous compartment selection remain the existing configuration interface.

## Existing owners and actual implementation

The allocated irrigation state already contains `management.event` and
`management.policy`. Previously the sensor preparation passed only the event,
so the existing DAYFIX counter could not participate. Optional existing policy
input/output is appended to the existing sensor preparation and standalone
wrapper; the allocated path passes its existing policy member. Enabled intervals
without policy state fail closed. The physical caller publishes event, counter,
selection day and allocation only after acceptance. Active events keep their
selected rate/end and do not recalculate depth or advance DAYFIX. No state owner,
calendar, numerical policy, reference correction or restart codec is added.

The already-admitted historical activation uses current accepted weather time,
immutable existing crop periods and actual emergence. STARTIRR/ENDIRR, winter
bounds, source leap-year arithmetic and native configuration format are unchanged.
Their source bytes are frozen; current native reconstruction retains the shared
counter and rejects wrong interval/domain, dates, calendar and schedule.

The original DAYFIX recurrence is extracted from the existing root policy into
one pure routine. Root callers use it only when the option is enabled, preserving
TCS6's independently advanced weekly candidate. Sensor trigger calculation is
exposed from the existing process, retaining inclusive source `<=`. TCSFIX is
applied before DCS1/DCS2, DCSLIM, salinity, rate and availability. The selected
sensor timing, rather than irrelevant timing metadata on the depth-only policy,
determines the TCS6 conflict check. A physical fixture deliberately supplies
that irrelevant depth timing6 while actual sensor timing7 remains source-valid.

Sensor AFGEN now supports explicit1..7 typed knot prefixes and upper endpoint
clamping. A one-knot prefix is constant. The source oracle explicitly normalizes
the unused tail; no deterministic behaviour of uninitialized legacy raw arrays
is assumed. Interpolation uses historical slope-then-multiply order. The last
knot is still evaluated by source interpolation; only strictly larger arguments
clamp directly to the last value.

## Defects and discriminating evidence

The exact source test exposed the final-knot arithmetic difference on a seven-knot
TCS7 table at DVS2: the source gives **-499950.00000000006**, while an early clamp
gave **-499950.00000000000**. The original failure and diagnostic output remain
archived. No tolerance was relaxed: both optimized versions must match the
literal threshold exactly and reproduce source trigger decisions.

Code review caught a preliminary extraction that would overwrite TCS6's candidate
when the interval option is disabled. The call is now enabled-only; unchanged
weekly physical/native endpoints are checked directly. Werror also caught an
unused variable after trigger extraction; the declaration was removed. These
failures are retained, rather than reclassified as successful qualification.

Authenticated B1.11 `SWAP/irrigation.f90`, SHA256
`65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1`,
provides the exact TCS7/TCS8/TCSFIX blocks. Authenticated `functions.f90` provides
the literal AFGEN. The original archive and preceding science/admission capsules
are frozen against the pinned baseline.

## Proportionate qualification

| Level | Evidence |
| --- | --- |
| A, changed physics |2,604 literal sensor/AFGEN/interval cases per O0/O2;1..7 knots, interior/endpoints, inclusive sides, wet/dry counter saturation, intervals1/3/366; six contiguous spatial supports plus invalid tables/nodes/layouts |
| A, shared preservation |2,079 root TCS2/3/4+DCS1 source cases,4,452 interval transitions,934 LIMIT cases and eight original management/application/restart executables, O0/O2 |
| A, unchanged interfaces |72 original seasonal boundary cases and360 heterogeneous/fractional-root cases per optimization; unchanged source/flags/native outputs compared with the preceding capsule |
| B, real production | Seven profiles share one fresh297-provider and10-oracle build per optimization;126 trajectories and264 CRC-correct native negatives |
| B, state/physical boundaries | Actual accepted weather, soil pressure/moisture, SWRD2 roots and material DCS1 refill; hard mass, actual incomplete Richards candidate, rollback/smaller retry, once-only day/counter/events, opaque/fresh native and an in-flight gift |
| C, admission | Exact production/test postimages, generated literal/source identity, raw commands/output hashes, frozen pre-code contract, original qualified incumbent proof and35 unchanged controls, new evidence negatives and owning/reference entrypoints |

The four changed profiles are TCS7 winter/DCS1, TCS8 annual/DCS2 with one-knot
typed tables, winter three-compartment TCS8/DCS1 and schedule off. Preserved
representatives are the existing seasonal root TCS3, weekly DCS1 and AVAIL root
profile. All continuous/opaque/resumed/active native endpoints must match, as
must O0/O2 stdout. Twelve full default native endpoint files are compared with
the original full PR1272 capsule. Source/direct tests independently cover sensor
threshold crossings; real production supplies evolving accepted sensor values.

The existing optional interfaces are source-compatible, not an exemption from
recompilation. All current297 providers, including old optional-argument callers,
are rebuilt. No cross-Session object reuse occurs. Unchanged source/reference,
solver and prior owner science remains bound to its admitted evidence. The
original incumbent proof preserves29 owner-successor receipt flags and all four
preceding root admissions. This is not29 new numerical campaigns. No full F-CI,
RossFast, highest low-air or hosted Actions is selected by an import alone.

Calendar/material source and original tests are unchanged. Their toolchain bytes
and host match, but the stored opaque all-environment hash differs and does not
retain the original environment values. Four small native checks were therefore
executed again, for 6.735s combined, rather than asserting unchanged execution identity.
This is an observed evidence-workflow cost; it does not justify a global solver
rerun. Original literal assertions and numerical outputs remain exact.

## Measurements and critical evaluation

Final selected science controllers total **623.663s**;
physical controller **609.122s**. There are34 linked
test executables and410 native invocations in the selected terminal qualification.
All instrumented attempts, including superseded/failed direct tests, contain
772 compilation invocations,
40 links and
416 native invocations. Raw commands,
compiler flags, inputs and timings remain archived. Compile-and-link commands
with source files count in both categories. Parent controller time is not added
again to child command time.

Two earlier uninstrumented shell attempts are retained separately. One fails at
O0 Werror before any native run; the other completes the unchanged24-compile,
eight-link/eight-native script. Their complete elapsed times were not recorded.
They are not hidden in an exact all-attempt runtime total. Initial reconciliation
and a complete source-analysis/implementation/coordination split remain UNKNOWN.
The instrumented phase through science sealing spans
1030.061s, an elapsed duration,
not a reconstructed active engineering timer.

For the three admitted whole rows, selected terminal science costs
**207.888s per row**, versus prior single-row terminal
physical observations493.791s(TCS6) and578.325s(AVAIL), mean536.058s. The workloads
differ and historical coordination totals are UNKNOWN. Therefore the complete
qualification-plus-coordination experiment remains **INCONCLUSIVE**, regardless
of a successful merge. Source, mass and state gates demonstrate declared
reliability; they do not prove universal reliability or portable speed.

The earlier root-only package treated the sensor interface as an exclusion.
This continuation shows that the missing state path is a small extension inside
existing ownership, with no second architecture. The initial functional grouping
was therefore conservative: assessing this bridge before the first qualification
could have grouped these seven rows earlier. A combined counterfactual campaign
was not measured; no invented runtime saving is reported. Actual repeated builds,
three duplicated preservation representatives and environment-fingerprint checks
expose workflow overhead. The equations do not require separate campaigns.

## Admission and remaining work

Full science,32 new fail-closed admission controls and four existing owning/reference
entrypoints pass. The admission controller takes36.635s. Exact-tree merge and
master promotion follow these qualification results.
Only after all owning gates and safe qualified-tree canonical merge may the
three existing master rows be promoted. Preserve all other240 capability records,
including PR1272's four admissions. Recovery holds the final exact merge and
master receipt. The remaining independent irrigation row is SALTEXCESS, requiring
accepted bottom7 chemistry/weather composition through existing owners.

All-attempt command counts including reconstructed uninstrumented strict-shell
control flow are **802 compilation invocations,48 links,424 native invocations**.
The raw Session counts above remain772/40/416; the additional failed six-compile
O0 prefix and completed24-compile/eight-link/eight-native shell are distinguished
in recovery. No elapsed time is invented for either uninstrumented shell.

## Canonical completion receipt

Three complete existing rows are **ADMITTED** by PR1273, canonical merge
`dc6c80ee1ad6af20b74e5beb6fcc4a7e9a8f2e4e`, qualified head `0b2fe122dbb3e0ffaa724fd725d5585e8c173d83`.
The complete merged tree exactly equals `3386518a39919d8ce709733c6491ae04eaf354a3`;
source `bae023dab2bb91a91d6a48c4d2a5429a94897873`. Postmerge source/science
validation passes. Master receipt `c5d6a675c321024a8488d2eeaa39b62000e3fae3`
promotes exactly TCS7/TCS8/SSDI and preserves all other240 capability records,
including the four earlier PR1272 admissions. Source/census/pinned-locator
integrity,20 inheritance controls and source/strict docs pass.

Current counts: **243 total,112 ADMITTED,92 ACTIVE_MIGRATION,3 QUALIFICATION_ONLY,
14 SUPERSEDED,2 REJECTED,20 NOT_APPLICABLE;95 unresolved**. MC-IRR01 has15/16
existing rows admitted; only SALTEXCESS remains open. Issue1271 has closed7
complete rows across two coherent PRs. The global denominator remains incomplete.
The complete qualification-plus-coordination speed criterion remains inconclusive
because historical category timers are unavailable.
