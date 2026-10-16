# MC-IRR01 batch experiment, issue 1271

## Authority and scientific question

[Issue 1271](https://github.com/abhedwig-cell/SWAP5/issues/1271) authorizes one
coherent migration campaign, not weaker scientific admission. This candidate is
[PR 1272](https://github.com/abhedwig-cell/SWAP5/pull/1272). Its recovery authority
is the existing `MC_IRR01_STATUS.json` field `batch_experiment_1271_20261017`.
PR 1268 completed independently before implementation. The experiment production
baseline is `121ed3503638c2d3168fa30e40f6af24156348a7`; the later `f5504d30`
canonical change only seals that LIMIT admission and master receipt.

The hypothesis concerns qualification and coordination time **per fully admitted
existing capability**, with at least two such admissions. Counting parameter
cases, a PR, or a partial option implementation cannot establish success.

## Shared implementation and scope

The selected root-policy package comprises existing TCS2, TCS3, TCS4 and DCS1.
The root/material/weather implementation already exists. The concrete missing
composition implemented here is historical `TCSFIX=1` with `IRGDAYFIX=1..366`
through those selectors. Minimum interval is already admitted for the separate
bounded TCS1+DCS2 route; this is not a new capability or a second TCS1 migration.

Authenticated B1.11 `SWAP/irrigation.f90`, SHA256
`65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1`,
sets DAYFIX to one on an eligible triggered gift, advances a suppressed counter
only while below IRGDAYFIX, and preserves a saturated counter on a nontrigger.
It forbids TCS6 together with TCSFIX. The literal recurrence is extracted into
the test include and verified against that exact archived source before builds.

The existing root management policy now uses its existing DAYFIX storage for
this option. Accepted-day dispatch and transaction acceptance remain the owners
of whether a candidate counter is published. No independent clock, calendar,
restart owner, physics tolerance or water accounting is introduced.

The generic management restart validates DAYFIX through 366. The weather
reconstruction additionally checks its configured domain, retaining the original
TCS6 rejection domain when TCSFIX is disabled. Sensor preparation currently
passes event state without root-policy state. It explicitly rejects this new
option until its existing interface is extended; silently ignoring the option
would be incorrect. SALTEXCESS still needs the separately unadmitted bottom7
chemical/weather composition.

## Persistence and test selection

Adding derived-type configuration fields would otherwise change even default
native files. The existing codec now emits the original policy components in
their original order. Disabled TCSFIX retains original bytes; enabled TCSFIX
adds an identified interval configuration extension in the existing config block.
The expected configuration remains caller-owned and mismatches fail atomically.
This is the same codec and tag, not a replacement persistence architecture.

The direct O0/O2 driver executes 4,452 source transitions per optimization,
including maximum interval saturation, wet/no-trigger days, nonmutation,
existing restart round trips and invalid interval/overflow/conflicting options.

The actual composition uses three selectors and one unchanged weekly
representative. Each O0/O2 build compiles the same 296 production providers and
ten historical/oracle providers once, then links and executes every selected
program. It retains authentic weather, evolving accepted SWRD2 roots, material
moisture thresholds, Richards acceptance, hard water balance, rejected trial,
retry/replay, opaque continuation, and fresh native endpoints. Existing native
corruption controls are extended with an optional interval domain; default
controls keep their original assertions. No solver/stress/full F-CI run is
selected merely because irrigation inputs or configuration values changed.

Measured terminal results, failures, compiler flags, inputs, commands, raw
outputs, counts and evidence hashes are recorded in the existing recovery
field. Tests are not called complete before their controller terminates.

## Limits of closure and comparison

The full selected capability rows retain historical activation and profile
conditions. In the current bootstrap, `schedule_enabled` and
`irrigation_window_open` are set true rather than derived from historical
STARTIRR/ENDIRR and crop-season boundaries. These bounds are not supplied by the
root policy's current interface. Removing that gate or calling an always-open
season a full historical envelope would overstate migration. Broader historical
selector/material/geometry envelopes also remain separate original row gates.
No master row can be promoted solely from the interval results.

The retained TCS6 terminal physical evidence records 493.791 seconds, 616 compile
invocations and 264 native program invocations. AVAIL records 578.325 seconds,
22 compile invocations and 604 native program invocations with verified provider
reuse. Those counts include scientific and corruption programs; direct
compile/link commands need separate classification because some runners compile
multiple sources in one invocation. Prior failed/reconciliation histories must
not be added to parent totals twice. Historical analysis and bookkeeping time
are UNKNOWN, so these observations cannot prove a reduction in total engineering
or coordination time by themselves.

A failed controller also exposes an execution-cost issue: the current protocol
permits provider reuse only within one live Session. A fixture correction after
controller failure therefore selects a fresh build even with unchanged physics.
This is an observed test-workflow cost, not evidence that water equations demand
those repeated compilations. No cross-session reuse exception is assumed here.

The experiment cannot succeed without two full row closures. Its outcome must
remain incomplete/inconclusive if only this common option is qualified. The
remaining barrier is application activation/interface scope and complete-row
qualification, with additional workflow overhead. It is not evidence that the
three root-trigger equations require separate migration campaigns.

## Recorded terminal observation

The persisted execution candidate is
`dcb8de76c9d90cbf2a5a52b9f4f2863e39130819`. Its focused physical controller
completed in 401.950 seconds. Both optimizations passed 72 trajectory invocations
and 240 checksum-correct/native rejection invocations in total. The direct final
controller took 1.698 seconds and the incumbent small preservation controller
2.736 seconds. The combined terminal qualification cost is 406.385 seconds;
these totals are not added again to their child command times.

Including the retained failed physical attempt and direct preflight, the actual
observed counts are 987 compile invocations, 21 link invocations and 325 native
program invocations. The instrumented implementation/qualification phase through
evidence sealing spans 799.472 seconds. Earlier reconciliation and the failed
physical controller's full elapsed time are UNKNOWN; its retained commands total
45.064 seconds. A complete engineering-time split cannot be reconstructed by
inventing missing timers.

All four fresh default weekly native full endpoints match the original LIMIT
capsule exactly. No old physical PASS substituted for fresh execution. Historical
forcing and independent oracles were reused. Unchanged solver/stress suites were
not selected; omitted tests are not reported as newly passing.

**Outcome: zero full capability admissions, no canonical merge, no master
promotion.** PR 1272 remains a draft. The success threshold is unmet and the
speed/reliability hypothesis is inconclusive. In particular, 401.950 seconds
must not be divided by four and reported as time per closed capability.

The observed master receipt is `6bad61262c2a510c8048b81d5a930f391b7d634e`:
243 total, 105 ADMITTED, 99 ACTIVE_MIGRATION, 14 SUPERSEDED, 2 REJECTED,
20 NOT_APPLICABLE and 3 QUALIFICATION_ONLY, hence 102 unresolved. These counts
include the independent LIMIT admission and no experiment promotion. The existing
recovery field and its hashed raw capsule preserve the exact measurements and
remaining admission gates.
