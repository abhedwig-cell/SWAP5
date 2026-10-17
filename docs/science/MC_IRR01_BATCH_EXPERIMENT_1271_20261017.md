# MC-IRR01 coherent irrigation migration experiment, issue 1271

## Authority and hypothesis

[Issue1271](https://github.com/abhedwig-cell/SWAP5/issues/1271) authorizes this
actual migration in existing [PR1272](https://github.com/abhedwig-cell/SWAP5/pull/1272).
Recovery is `MC_IRR01_STATUS.json`, `batch_experiment_1271_20261017.resume_20261017`.
PR1268 LIMIT was merged separately before implementation. The admission baseline
is `f5504d30391baff52143ac6441ba231264cee5a0`; canonical
`48fb7fa3a9df7561efff4ee845a4e46341c3e45f` adds only publication documents.
The four existing selected rows are **TCS2, TCS3, TCS4 and DCS1**. No new
capability, calendar, state owner, codec, framework or governance register is created.

The frozen hypothesis requires at least two whole-row canonical admissions and
lower qualification plus coordination effort per admitted row, with unchanged
scientific reliability. Parameter cases or one merged PR cannot establish success.
The frozen closure conditions remain byte-semantically unchanged from `90167ddb`.

## Actual implementation and source qualification

The historical authority is B1.11 `SWAP/irrigation.f90`, SHA256
`65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1`.
The existing policy's DAYFIX now implements TCSFIX/IRGDAYFIX1..366 across the
three root selectors. It advances only at eligible accepted-day selection,
resets to1 after an eligible trigger and saturates without a trigger. TCS6 with
TCSFIX is rejected as in the source. Existing management restart owns the counter.

Historical STARTIRR/ENDIRR activation now consumes accepted weather Gregorian
time, existing immutable `crop_calendar_t` periods and accepted crop emergence.
A readonly plan snapshot and inverse-year function extend those existing owners.
Same-year crops compare days since actual Jan1 with1900 offsets, including the
historical leap-year offset quirk. Cross-year bounds use crop first/last years,
strict lower `>1e-3` and inclusive upper `<=1e-3`; annual lower is `>=-1e-3`.
The plan creates no crop emergence or transition. Disabled activation preserves
the established route. Native configuration binds the interval, schedule,
dates and immutable plan inside the existing codec; default bytes remain exact.

The complete typed parameter partitions cover1..7 AFGEN knots, end clamping,
interior interpolation, strict trigger boundaries, rainfall subtraction,
under/over refill and invalid input. One-knot tests explicitly normalize the
unused source table tail to a descending sentinel. They qualify a constant typed
AFGEN prefix; they do not claim migration of generic legacy parsing or
unspecified/uninitialized raw source tails.

Two production defects were found, with original failures retained:

* The literal AFGEN boundary comparison caught a four-knot TCS2 case at DVS1
  and7cm available water: division before multiplication rounded the old
  threshold to0.49999999999999989 and incorrectly triggered. The policy now uses
  the exact historical slope-then-multiply operation order.
* The invalid-domain O0 test caught SIGFPE on a NaN rainfall threshold. Fortran
  need not short circuit logical operands. Finite rejection now precedes ordered
  comparisons. No valid-domain formula or tolerance was relaxed.

A native negative fixture also attempted to change season4 Jan30 into Jan30.
Correct acceptance of an identical configuration exposed the fixture mistake.
The witness now uses distinct valid Feb1, with a generator assertion. The failed
controller is retained, rather than counted as a pass. Earlier interval fixture
and closure/generator failures remain in the original immutable capsule.

## Proportionate qualification and inheritance

| Level | Actual evidence on the selected postimage |
| --- | --- |
| A, policy physics | O0/O2 exact authenticated source blocks:2,079 TCS2/3/4+DCS1 comparisons and10 invalid domains per optimization;4,452 literal interval transitions;934 LIMIT preservation cases |
| A, existing interfaces |72 literal seasonal boundary cases per optimization, schedule/off/outside/invalid/leap checks and Gregorian inverse endpoints for years1..9999;360 heterogeneous material/fractional-root cases, invalid inputs and ABA |
| B, real production | One fresh297-provider plus10 historical/oracle build per optimization; six drivers,108 trajectory programs and264 CRC-correct native rejection programs |
| B, persistence | Current accepted SWRD2 roots/material moisture, actual weather/rain, Richards acceptance, original hard mass assertions, rejected trials/replay, once-only day/counter/event selection, opaque and fresh native continuation; in-flight seasonal gift checkpoint |
| C, admission | Exact source/test postimages, source-generated oracles, raw command/output hashes, default TCS6 and AVAIL endpoint bytes compared with the immutable LIMIT capsule, incumbent proof and original29 controls, new fail-closed evidence controls and owning entry points |

The six profiles are seasonal TCS2 winter window, seasonal TCS3 annual window,
seasonal TCS4 with one-knot typed tables, schedule off, unchanged weekly DCS1
and unchanged AVAIL. Both optimization outputs and all continuous/opaque/fresh
native endpoints are exact. Native rejection binds changed dates, calendar,
schedule, counter domain and the retained corruption cases.

The immutable incumbent proof was rerun at canonical48fb with the same source
tree asf550. Its28 existing owner-successor receipt flags are preserved; this
is not28 new numerical runs. Relevant changed root/policy/config/restart seams
receive fresh targeted evidence above. Unchanged drainage, solvers, crop physics,
reference files, historical forcing and oracles inherit their bound evidence.
RossFast, highest low-air, full F-CI and hosted Actions are NOT_SELECTED, not
new PASS claims. Broader solver runs cannot distinguish these changes better
than the direct source and real accepted-state tests.

Original full-row restrictions were reconciled explicitly. Accepted evolving
root/material binding, real rain deduction, weekly progression and native weather
restart have canonical predecessors; this package closes the missing own
parameter, interval and historical activation envelope. Heterogeneous materials
and partial root cells are checked at the real minimal material interface.
Independently unadmitted HYD/POWER, salt and crop variants keep their own gates,
as for already admitted AVAIL/LIMIT. They are not silently promoted or added as
automatic dependencies of every irrigation selector. Full row admission concerns
the selected own source contract through admitted physical profiles.

## Measurements and critical comparison

All times are observed, not synthetic benchmark data. Parent controller times
are not added to their child command times. Compilation invocations with source
files that also link are counted in both compilation and link categories;
`compile_only_invocations` preserves the narrower count for audit.

| Observation | Measured result |
| --- | --- |
| Earlier single-row TCS6 terminal physical controller |493.791s,1 closed row,616 compile-only invocations,264 native invocations |
| Earlier single-row AVAIL terminal physical controller |578.325s,1 closed row,22 compile-only invocations with verified reused providers,604 native invocations |
| Final full batch physical controller |517.363s |
| Final batch selected qualification controllers combined |530.066s,30 linked test executables,390 native invocations |
| All resumed attempts including failed and superseded work |1134 compilation invocations,55 links,547 native invocations |
| First partial campaign, retained separately |987 compile-only invocations,21 links,325 native invocations;406.385s successful terminal qualification;799.472s instrumented elapsed |
| Final batch qualification per admitted row |132.516s |
| Both successful partial and final qualification phases per admitted row |234.113s |
| Earlier mean terminal physical cost per full row |536.058s |
| Source analysis/implementation category |UNKNOWN; no complete continuous timer |
| Evidence/recovery/coordination and total engineering time |UNKNOWN; historical campaigns lack comparable category timers |

The resumed instrumented phase through evidence sealing spans
1532.211s; this elapsed session duration is
not an invented active development total. Failed controller elapsed totals that
were not recorded remain UNKNOWN; executed command durations are retained.
See the recovery attempt ledger and raw capsules for all measurements.

Shared qualification lowers observed successful terminal controller time per
row if all four are admitted. These are different physical scenarios, not a
controlled same-workload speed benchmark. More importantly, the complete
qualification-plus-coordination success criterion is **INCONCLUSIVE** because
historical coordination/engineering timings are missing. No reliability loss was
observed in the declared source/mass/transaction/restart gates, but that is not a
universal reliability proof.

The first partial campaign correctly closed zero rows; its bootstrap lacked
historical activation. Resuming the same PR resolved that interface through
existing owners. The observed limitation was application binding and test
workflow overhead, not a need for separate root-trigger physics campaigns.
Failed fixture controllers required rebuilding unchanged providers in a new
Session. The batch still pays that cost, and the attempt totals expose it.

## Admission and remaining work

The full science, batch admission validator,35 fail-closed evidence controls and
four existing owning/reference entrypoints pass. Admission verification took
44.850s in one parallel controller. Four complete existing rows are now canonically admitted by PR1272 at
`bda0d91eb3deb99e450926d0cd8ea134e2e7eb5c`. Qualified head `841078b7c4cf3c85a1b2b31ab7cd3159d1936d1e`;
full merge tree exactly equals `1b9441ebee5258154db683b416601e525418f607`,
source `ecc1249b9c4fc012b3382011b7c630ce98b42e60`. Postmerge source/science
validation passes. Existing master branch receipt `1afb72288e88333b45c061cca78b87e4ca51c780`
promotes precisely those four rows and preserves the other239 capability records.
Counts are **243 total,109 ADMITTED,95 ACTIVE_MIGRATION,3 QUALIFICATION_ONLY,
14 SUPERSEDED,2 REJECTED,20 NOT_APPLICABLE,98 unresolved**. Historical-source
and pinned-locator integrity,20 inheritance controls and source/strict docs pass.
The global coverage denominator remains incomplete. The full speed experiment
remains inconclusive because coordination/engineering baseline timers are absent.

Across both experiment phases, including retained failed and superseded attempts,
actual execution totals are2,121 compilation invocations,76 links and872 native
Fortran program invocations. Final selected science alone uses710 compilation
invocations,30 links and390 native invocations. Six Python admission entrypoints
are measured separately. These totals expose repeated failed-controller builds;
they are not presented as a reduction in total compilation count.

TCS7, TCS8 and SSDI still need the existing event-only sensor preparation boundary
to carry management DAYFIX state. SALTEXCESS still requires accepted bottom7
chemical/weather composition. No second counter or route was introduced to
bypass those dependencies. Other239 master rows must remain unchanged.
