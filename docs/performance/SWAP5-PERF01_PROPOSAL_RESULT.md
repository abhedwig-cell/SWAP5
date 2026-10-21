# PERF01 optional production proposal: qualification result

Follow-up historical [dry infiltration diagnosis](SWAP5-PERF01_DRY_DIAGNOSIS.md)
identifies total-balance stagnation in four O0/O2, OFF/ON probes. It does not
correct the solver or qualify the excluded long infiltrating dry32 regime.

21 October 2026. Locally qualified bounded production implementation; default
OFF. Actual canonical admission is recorded by the work-unit PR and its owning
status. Starting baseline `9c16572a`, composed with admitted nonlinear thermal
canonical `e61d8e107121bc31fa1d9b0eac73439af29eb76f` before final qualification.

## Implemented behaviour

The production canonical runtime now targets the exact requested endpoint
before solving when an optional proposed target is already within the existing
progress tolerance. Optional completion requires an exactly matching accepted
endpoint, including after solver fallback. No accepted state or trace is
relabelled. When an accepted transaction reports solver rejection, the proposal
is disabled for the remainder of the requested interval. Policy memory resets
at each new interval and is not physical or persistent state.

Only the optional execution policy changes. Full/half acceptance, solver and
retry limits, physical equations, mass checks, strict chemical endpoints and
restart schema remain intact. The column input additionally accepts
`retain_accepted_step_proposal=.true.` in `&column`. Omission means false for
both existing schemas. The shared typed configuration default remains false.
External target selectors and model-certified temporal mode remain incompatible
with the optional proposal. RossFast scope is unchanged.

See the [production contract](SWAP5-PERF01_PROPOSAL_CONTRACT.md). The scientific
source successor admits exactly two production/application postimages, one new
runtime test and two precise authority handoffs. All other scientific source
and reference changes relative to the composed baseline fail closed.

## Measured error and cost over one day

The three completed longer inputs cover 24 hours, compared with 0.008 day in
the preceding study. There are 64 reporting intervals. Rainfall in the pulse
case remains constant within the original sixteen 1.5-hour forcing blocks;
each block is reported four times. Wet and quiet dry forcing are unchanged by
this reporting subdivision. Geometry and prescribed sinks remain the existing
production column inputs; this is not a live crop or regional application.

Four O2 tolerances are executed: 1e-6, 2.5e-7, 6.25e-8 and 1e-8. Both finest
routes are finite numerical references, not exact solutions. For each default
1e-6 run, select the tested proposal with the least HeadCalc work whose maximum
head, theta and concentration errors do not exceed the default errors against
**either** reference. Tie-breaks use nonlinear iterations, attempts and coarser
tolerance. This deterministic choice does not select on noisy single timings.
Then execute three fresh interleaved paired repeats of the selected policies.

| One-day case | Default tolerance | Proposal tolerance | Default median CPU s | Proposal median CPU s | Default / proposal |
| --- | ---: | ---: | ---: | ---: | ---: |
| Wet4 | 1e-6 | 2.5e-7 | 4.218707 | 0.857535 | 4.92 |
| Pulse4 | 1e-6 | 2.5e-7 | 4.222752 | 0.839200 | 5.03 |
| Quiet dry32, no surface supply | 1e-6 | 1e-6 | 0.008748 | 0.008966 | 0.98 |

CPU covers only the actual joint water/solute interval call. Input, compilation
and diagnostic snapshots/output outside that call are excluded. Raw timing
samples are retained. GNU Fortran 13.3.0, O2 production; no new hosted compiler
footprint or portable speed guarantee. The dry control is approximately parity
and has identical numeric work under both policies. At coarse tolerance it has
no solver rejection, so it cannot alone establish dry solver robustness.

For wet4, HeadCalc calls fall from 487731 to 90456, nonlinear iterations from
1631105 to 272064. Against the default fine reference, maximum head error falls
from 0.001960 to 0.001127 cm, theta error from 2.27e-6 to 1.31e-6, and
concentration error from 6.28e-7 to 3.56e-7 mg/cm³. Final water and solute
inventory differences also decrease. Pulse4 has corresponding head differences
0.001947 and 0.001121 cm, with HeadCalc calls 494742 and 91656. The same three
state-error comparisons hold against the proposal fine reference. Other flux
and inventory differences are reported individually, not silently included in
a universal scalar accuracy claim. Wet errors decrease under refinement; the
dry control has a coarse-tolerance plateau. No global error bound is established.

At equal tolerance the wet route is faster but slightly less accurate. Its
larger same-tolerance speed ratio is therefore not the headline result. The
fourfold stricter proposal tolerance retains the bounded fivefold cost gain.

## Failed regimes retained, not admitted

The first finest-reference wet4 run used sixteen reports. The default route
accepted 57136 two-half transactions in its first 0.0625-day window, requiring
114272 chemical trace segments. This exceeds the unchanged 100000-entry
consumer contract, so the chemical route rejects before external publication.
Both clocks stay zero. The same full-day forcing is rerun with 64 reports;
neither the trace limit nor scientific acceptance checks are relaxed.

A separate more difficult input applies surface supply to initially dry32 for
one day. Both default and optional routes exhaust solver retries in the sixth
window, requested [0.078125, 0.09375] day. Their completed partial budgets and
reported failure clocks match exactly. Both retain the previously committed
0.078125-day state, with no chemical step in the failed interval. These two
failed observations remain failures and this long infiltrating dry regime is
excluded from admission and speed/accuracy conclusions. Extending its solver
envelope is a separate work unit; no tolerance or retry-budget change is made.

The earlier short dry32 infiltration case does complete, preserves the prior
diagnostic candidate and its restart, and exercises the solver fallback. That
short success does not qualify the failed longer regime.

## Qualification and preservation

- The original analytic optional-policy test and new real runtime endpoint,
  fallback/reset, late solver failure, hard mass rejection and substep-exhaustion
  checks pass at O0/O2. The unchanged eight-provider direct runtime closure is
  measured, not a copied controller calculation.
- Fresh actual column builds contain 178 providers; checked O0 and production
  O2 are separate. All 86 original file/grid/budget/restart/publication/input
  observations pass without changing their scientific assertions.
- The selected short/day matrices have 204 completed observations, with 80
  shared O0/O2 observations exactly matching physical bytes and numeric work.
  All 32 policy/case/optimization split-restart combinations reproduce final
  state, endpoint and restart bytes and resumed reporting rows. Every default
  observer matches both the actual new executable and pinned incumbent files.
- All 20 short proposal case/tolerance trajectories and physical files match
  the preceding immutable diagnostic candidate exactly. Maximum selected-window
  residuals are 1.13e-12 cm water and 6.07e-13 mg/cm² solute.
- The original four runtime drivers execute freshly at O0/O2, eight observations
  with exactly preserved stdout. Their full executed source inventories remain
  identical after composition with the concurrent thermal admission.
- Current six-exponent thermal physical/restart/rollback/refinement/crash gates
  execute freshly at O0/O2. They reuse one fresh 277-provider build only after
  the original runner checks source and executable identities. All six physical
  results preserve the admitted predecessor exactly. The earlier linear-only
  run is retained under its own source identity, not rebound to the successor.
- The exact composed predecessor owner and its controls execute at their frozen
  canonical snapshot. The current owner checks new source, all raw inventories,
  generated observer, every changed runtime input, hard budgets, failure
  dispositions, restarts, optimization identity and paired raw replays. Thirteen
  corruption controls reject altered sources, foreign code, missing state,
  thermal/restart/predecessor/matched proof, stale runtime input and relabelled
  native failure. Existing thermal, atmosphere and age entrypoints still work.

The archive retains 222 column observations including two failures, the separate
failed optional dry probe, 18 matched-error timing observations, direct tests,
original column assertions, runtime preservation and both thermal execution
phases. All 8454 raw members have individual hashes and the compressed archive
has a SHA256. Compiler binaries/objects are excluded. Compile/link/native event
costs are retained where measured; concurrent preservation execution means their
wall times must not simply be summed as elapsed session time.

Full moving F-CI is replaced here only by the explicit owner-selected changed
runtime preservation set, never labelled a full F-CI PASS. The retired highest
low-air stress run is not selected. Original physical authorities remain bound
to their admitted predecessor; fresh current proof covers the actual changed
runtime paths. No master capability count is promoted.

## Use and recovery

In an existing qualified column input, add this line to `&column` only when the
bounded option is wanted:

```fortran
 retain_accepted_step_proposal=.true.
```

Use the existing column build and file runner. Both input and executable bytes
remain part of restart identity, so an old published generation is not silently
restarted with a changed executable. Direct typed applications likewise opt in
through their existing `canonical_numerical_config_t` field; this result does
not approve untested orchestration or physical regimes.

Recovery and proof: `integration/performance/SWAP5-PERF01_PROPOSAL_STATUS.json`,
`integration/performance/verify_proposal.py` and
`integration/performance/evidence/perf01-proposal-production-20261021/INDEX.json`.
Seasonal, regional HRU throughput, live crop/heat use of the optional route,
unsupported solver modes and the failed long dry infiltration case remain
outside this bounded admission. The nonlinear heat preservation here is for
the unchanged default-OFF route.
