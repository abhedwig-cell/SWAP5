# HYBRID-WATER01 donor day boundary

## SWAP5-FUNCTIONAL-CLOSURE01 workpoint

The consolidation branch is `codex/swap5-functional-closure01`. It starts
from the exact hybrid evidence head `0ca2e3edd7e869d2ac7d37ed6c139ae126fdcc49`
with canonical checked at `7535a9e650aa01ca3ee711353c2e2801e2872f00`.
PR 1619 remains the research baseline.

At a selected accepted cut, the daily adapter writes a closed ZIP with
the binary donor pair and its kernel receipt. It publishes that ZIP with
the native `swap5_restart_publish` file flush and atomic replacement.
The schema-2 manifest binds the accepted hydraulic state, pinned nested
archives, input hashes, profile and numerical build inputs. The build
identity includes the GNU Fortran driver, target, flags, rendered sources,
linked legacy objects and TTUTIL archive, module inputs and SWAP5 sources.
Executable hashes are recorded separately because independent links can
produce different bytes. Strict reopening verifies the identity and both
payload digests before extracting the exact verified bytes. It then checks
the donor's initial stocks and heads before the new kernel starts.
Historical schema-1 directories remain evidence of the earlier tests.
Strict reopening requires a schema-2 ZIP. The raw donor-directory mode
still exists for research replay.

On Windows GNU Fortran 16.2 O2 the own day-20 package reproduced
accepted days 21–22 exactly, after accounting for the new kernel
revision sequence. A run without the balance scheduler refused day 15
before its requested cut and published no package. Modified macro bytes,
an incorrect cut and an incorrect profile were each refused by the
package verifier. The previously evidenced 481-day trajectories were
reused.

```powershell
$ref = "$env:TEMP/hy481-local-b0-20261109"
$flags = @('--budget-retry', '--shared-pond-transfer', '--refresh-macro-final')
$runner = 'research/hybrid-water01/run_daily_kernel.py'
$published = "$env:TEMP/swap5-closure01-publish"
python -B $runner --reference-work $ref --output $published --checkpoint-at 20 --days 22 @flags
python -B $runner --reference-work $ref --output "$env:TEMP/swap5-closure01-resume" --origin "$published/accepted-column-1-day-20.zip" --origin-day 20 --days 22 --require-accepted-origin @flags
```

The published-package controls at day 256 and the year boundary (day
365) pass on GNU Fortran 16.2 O2. Days 257–258 and 366–367 match their
continuous controls exactly, including every daily receipt after
normalizing the new kernel revision counter, and both published rows.
Both continuous prefixes also match the full 481-day evidence exactly.
Maximum absolute independent water residuals are 2.202056e-8 cm and
3.959763e-7 cm respectively, inside the original 1e-6 cm gate.
The [accepted checkpoint receipt](CLOSURE01_ACCEPTED_CHECKPOINT_RESULT_20261109.json)
contains the four daily receipts, executable and input hashes and the
verified pair of checkpoint digests.

The [schema-2 durable checkpoint receipt](CLOSURE01_DURABLE_CHECKPOINT_RESULT_20261109.json)
records fresh Windows GNU Fortran 16.2 O2 runs for all three cuts.
Each continuation matches its continuous daily receipts and CSV rows
exactly after normalizing the new kernel revision. The day-256 and
day-365 continuous prefixes also match the earlier evidence exactly.
The largest independent water residual over the six resumed days is
3.959763e-7 cm, inside the original 1e-6 cm gate. The isolated day-20
pair matches both separate controls. The strict verifier refuses an
altered linked-object hash, changed payload, extra member or wrong day.

To reproduce, use the same reference and flags as above:

```powershell
foreach ($cut in @(256, 365)) {
    $published = "$env:TEMP/swap5-closure01-publish-$cut"
    $end = $cut + 2
    python -B $runner --reference-work $ref --output $published --checkpoint-at $cut --days $end @flags
    if ($LASTEXITCODE) { throw "Continuous run failed at cut $cut" }
    python -B $runner --reference-work $ref --output "$env:TEMP/swap5-closure01-resume-$cut" --origin "$published/accepted-column-1-day-$cut.zip" --origin-day $cut --days $end --require-accepted-origin @flags
    if ($LASTEXITCODE) { throw "Fresh continuation failed at cut $cut" }
}
```

Run the native publisher's O0/O2 controls with
`python -B tests/dataqual15/test_restart_publication.py --output "$env:TEMP/swap5-closure01-native-publish"`.
For the day-20 isolation control, reuse the verified donor bytes:

```powershell
python -B $runner --reference-work $ref --output "$env:TEMP/swap5-closure01-isolation20" --isolation --origin "$env:TEMP/swap5-closure01-resume/verified-origin" --origin-day 20 --days 22 @flags
```

Resume here. Move the verified worker and restart handshake into a
reusable host entry point that owns each column's clock and accepted
state, then extend the current selected-cut contract. The restart proof
covers a newly started process at an accepted day boundary. Storage
failure recovery and cross-build restarts are outside the verified scope.


Experimental proof on canonical base `7535a9e650aa01ca3ee711353c2e2801e2872f00`.
PR #1618 has a complete corrected V9 run and exact own-year replay. This
experiment uses the original sharp B0 donor and the unmodified Andelst inputs.

Run from the repository root with GNU Fortran 13.3.0:

```sh
python tools/vq/b0_source_runner.py --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/hybrid-b0 --case 3.macroporeflow
python research/hybrid-water01/run_day_return.py \
  --archive /path/to/SWAP_4.3.1.zip --reference-work /tmp/hybrid-b0 \
  --output /tmp/hybrid-day-return
```

The second command relinks three build-local donors: the loop return, a
four-call driver, and read-only full-precision stock/flux output. The solver
providers, original step selection and day-end process order come from B0.
All four windows completed and the standard daily series is exact against
the frozen B0 prefix. The largest independent recomputation of the donor's
reported daily water inventory residual is about 5.97e-7 cm. This is the
legacy ledger, with its own interception and snow conventions, not a new
SWAP5 kernel mass certificate.

The day-return test keeps one live donor process. In particular, the module
state and the local SAVE fields still live in the executable. A successful
return provides no fresh-process restart or A/B isolation proof. The next
implementation boundary is an explicit per-instance capture/restore of
continuation and attempt state, including TimeControl's saved clock,
HeadCalc's retained memory, BoundTop's atmospheric state, macro event
history, the crop and thermal continuations, and meteorological and output
cursors. The external Cauchy head, kernel rollback and SWAP5-owned commit
are also open. No canonical model or test gate has been altered.


## Balance-driven day stepping

Use `--budget-retry` to enable the Andelst step scheduler from day 15.
This keeps the first 14 days as a same-build control. The scheduler reads
the tentative matrix, pond, instantaneous-bypass macropore and Cauchy
terms before the donor publishes them. It asks the existing donor
rollback and timestep controller to retry if the predicted cumulative
imbalance exceeds the elapsed share of the SWAP5 daily allowance.
The hook runs after the donor's convergence checks and before recording
the step as a success. The original step floor still applies. SWAP5 checks
the actual whole-column daily ledger independently before publication.

This receipt is specific to the original Andelst bypass, snow and
bottom-boundary configuration. The step predictor covers the hydraulic
system below the canopy. The SWAP5 daily gate also includes canopy
stock and the other reported external water fluxes.

Prepare the original reference as described below. Then run from the
same PowerShell session using fresh directories:

```powershell
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced" --budget-retry --trace-richards --trace-day 33
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-cut2" --budget-retry --restart-at 2
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-cut20" --budget-retry --restart-at 20
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-cut256" --budget-retry --restart-at 256
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-year" --budget-retry --restart-at 365
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-dry" --budget-retry --restart-at 453
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-balanced-isolation" --budget-retry --isolation --days 20
```

### Measured result on the original Cauchy input

SWAP5 accepts day 15 at a residual of 7.810780e-7 cm and preserves the
original first 14 days exactly. Day 33 required one additional retry.
In its previous failing step, the surface balance expected 0.002479315 cm
to enter the macropores while the macro rates booked 0.002490494 cm.
The retry reduces that day's kernel residual to −2.187284e-8 cm.

The 481-day command commits through day 256 (1998-09-13) and refuses
day 257 (1998-09-14) at revision 256 with an independently measured
residual of −0.00113638236 cm. The largest absolute accepted daily
residual is 9.998896e-7 cm. The fresh donor and kernel from the day-256
checkpoint reproduce the refused day's heads, all stocks, all fluxes
and the residual. Of the 14,107 accepted donor steps in that private
day candidate, 10,625 are at or below the original 1e-5 day step floor.
They account for −0.00113569639 cm of the residual. The largest single
defect occurs at clock 36051.95550000457. The macropores book
5.8657444602e-5 cm of inflow while the surface balance accounts for
5.7133102179e-5 cm. Their difference of 1.52434242e-6 cm explains the
step defect. Independent controls cap the proposed steps on that day
at 0.001 and 0.00025 days. Both still refuse day 257.

The day-2 and day-20 fresh-process comparisons and the two-column
20-day isolation pass. The year and dry-window checks stop before
their checkpoints because the continuous SWAP5 origin fails at day
257. The research host leaves this candidate unpublished. The next
implementation question is whether the original surface and macro
routines can share one transfer at the wet contact while preserving
their physical equations and the native retry contract.

See [the balance-retry result](DAILY_BALANCE_RETRY_RESULT_20261109.json)
and [its evidence archive](DAILY_BALANCE_RETRY_EVIDENCE_20261109.zip).

### Shared lateral transfer experiment

The original `Pondrunoff` code can reduce the lateral transfer after
`MacroRate` has distributed it over the domains. At the largest day-257
defect, this reduces the surface transfer from 5.5962707760e-5 cm to
5.4438365337e-5 cm and leaves the already distributed domain rates higher
by 1.5243424231e-6 cm. A separate diagnostic that adds redistributed
excess to the already accepted rates in `MacroRate` reproduces the
same refusal.

Use `--shared-pond-transfer` with `--budget-retry` to test sharing the
original surface cap. When `Pondrunoff` reduces the transfer, the adapter
applies that same cap to the accepted lateral macropore rates in
proportion to their existing shares. Vertical inflow and the original
hydraulic equations, native step floor and tolerance values retain
their original definitions. The correction is scoped to day 257 and later
so the balance scheduler can preserve the first 256 accepted days. An
earlier trial activating the correction from day 15 changed the trajectory
and refused day 162 at 3.796380e-6 cm. The scheduling-only control remains
available by omitting the shared-transfer option.

A cold run from the original initialization with `--budget-retry
--shared-pond-transfer` accepts all 481 days, January 1, 1998 through April
26, 1999. The largest independent daily water residual is 9.998896e-7 cm
on day 215 and the signed sum is −3.098562e-5 cm. Days 257 and 258 close
at kernel residuals of 3.767075e-9 and 2.202054e-8 cm. The scheduling-only
control and the cold corrected run agree exactly through day 256.
The full run matches the entire fresh-process continuation from the
day-256 checkpoint. Days 2→4, 20→22, 365→367 and 453→457 reproduce the
continuous pressure heads, water stocks, fluxes and published records.
The two-column test passes for days 1–20 and a separate isolation test
passes across the corrected wet window at days 257–258.

Use the commands above with fresh output directories and append
`--shared-pond-transfer` to each command. The result and archive include
the original and resumed input hashes, the Cauchy perturbations for the
isolation tests and the full accepted daily ledgers. Compared with the
unmodified donor on the same compiler, the first published difference
is on day 15. The largest absolute drainage difference is 0.01135 cm on
day 258 and the largest groundwater-level difference is 84.3344 cm on
day 458. These are trajectory comparisons and are separate from the
mass acceptance and exact-restart evidence.

See [the full result](DAILY_BALANCED_RESULT_20261109.json)
and [its evidence archive](DAILY_BALANCED_EVIDENCE_20261109.zip).


### Groundwater deviation on days 457 and 458

The first published departure from the same-compiler original donor is
+0.00029 cm on day 15. The balance scheduler retries 1,949 steps on that
day. Day 457 is the first daily difference above 10 cm (+10.88535 cm).
The largest daily difference is −84.33440 cm on day 458 (1999-04-03).
The native and corrected trajectories both visit deep states on day 457.
Their first accepted level below −130 cm occurs at model clock
36251.941259245505 and 36251.82481645328 respectively. This distinction
separates the first published difference from the onset of the large
local excursions. The comparison does not identify a unique January
step that is sufficient to cause the April result.

The following fresh-process controls use original and corrected day-453
checkpoints with the same forcing. The two own-profile cases reproduce
their published day-458 levels exactly.

| Day-453 checkpoint | Original step policy | Balance scheduler and shared transfer |
| --- | ---: | ---: |
| Original | −78.08553 cm | −162.36759 cm |
| Corrected | −77.98819 cm | −162.41993 cm |

On the corrected checkpoint, the scheduler alone reproduces the complete
daily GWL sequence of the combined profile. In the final accepted step
of day 458 its incoming GWL is −77.910974 cm. The solution changes the
zero crossing from nodes 55–56 to nodes 80–81 and the bottom inward
rate reaches 2.549869 cm/day. Splitting the final proposed step in two
retains a deep endpoint (−160.42973 cm).

The same-prefix intervention recomputes `MACROPORE(2)` on every
`HeadCalc` residual evaluation of the final window. The preceding
25,048 accepted trace records and the first evaluation of the final
step match the scheduler-only control exactly. The first differing
evaluation retains −5.311980 cm/day of net macro-to-matrix exchange
under the original reuse branch and measures +133.472818 cm/day under
recomputation. The recomputed trial follows a different iteration and
retry path and ends at −77.82077 cm. The experiment isolates sensitivity
to reuse of the macro rate in the last nonlinear solve. The change in
the reported water table follows the computed pressure profile.
Recomputation is confined to the replay driver. This experiment does
not qualify it as a numerical policy for the full project.

Prepare `$ref` using the original donor command above. The `--origin`
directory must contain the own day-453 `result.end` and `macro.bin`
from the relevant continuous window. The `--prepared` directory is the
resumed day-453 case generated by that window with its `swap.swp` and
`swap.bbc`. Both profiles use the same original forcing. For the
same-prefix control and intervention, use the corrected origin and run:

```powershell
python -B "$probe/replay_groundwater.py" --reference $ref --origin $correctedOrigin --prepared $prepared453 --output "$env:TEMP/hy481-gwl-control" --budget-only
python -B "$probe/replay_groundwater.py" --reference $ref --origin $correctedOrigin --prepared $prepared453 --output "$env:TEMP/hy481-gwl-refresh" --budget-only --refresh-macro-final
```

Omit both switches to replay the original stepping policy, use
`--corrected` for both research options and add `--split-final` to test
the final half-step proposal. Each command needs a fresh output directory.
The original tolerance values apply in every case. The paired replay
driver runs in private donor directories. The existing full SWAP5
qualification remains the source of the accepted daily mass evidence.

See [the groundwater result](GROUNDWATER_REPLAY_RESULT_20261109.json)
and [the selected step and solver traces](GROUNDWATER_REPLAY_EVIDENCE_20261109.zip).


### Full-period trial of the final-step recomputation

The optional `--refresh-macro-final` switch carries the exact clock
window of the diagnostic into the regular daily kernel runner. It requests
fresh macro rates during the existing `HeadCalc` evaluations that start
at clock 36252.9989 through the end of day 458. The donor retains its
ordinary convergence tests and retry sequence. The SWAP5 daily mass
gate remains active.

Use the full, restart and isolation commands above with fresh output
directories and add `--shared-pond-transfer --refresh-macro-final`.
The following additional controls cross the actual recomputation
window. Use the corrected continuous day-453 checkpoint (the intervention
has yet to run at that checkpoint).

```powershell
$flags = @('--budget-retry', '--shared-pond-transfer', '--refresh-macro-final')
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-refresh-full" @flags
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-refresh-cross458" @flags --origin $correctedOrigin --origin-day 453 --days 459
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-refresh-isolation458" @flags --origin $correctedOrigin --origin-day 453 --days 459 --isolation
```

With `--origin`, the kernel starts a new revision sequence on the
supplied own checkpoint. In isolation mode, the shifted column
perturbs one Cauchy-table entry by +0.001 cm at the resumed start
date for post-year checkpoints. The original and perturbed columns
have separate workers and each is compared with its own single-column
control.


The cold run accepts all 481 days, with the same accepted daily records
as the previous profile through day 457. At day 458 the published
groundwater level is −77.82077 cm, compared with −162.41993 cm for the
previous profile and −78.08553 cm for the same-compiler original donor.
The absolute discrepancy from the original donor falls from 84.33440 cm
to 0.26476 cm on that day. Over all 481 days, the largest remaining
absolute discrepancy is 10.88535 cm on day 457. The largest day-to-day
change in the trial is +67.44652 cm on day 257, close to the original
donor's +67.44455 cm on the same day. These comparisons cover daily
outputs. They do not measure every subdaily groundwater excursion or
qualify forced recomputation at other clock times.

The independent daily water budget closes within 1e-6 cm on every day.
Its largest absolute residual is 9.998896e-7 cm. The restart windows
2→4, 20→22, 365→367 and 453→457 match the continuous run exactly.
Continuations 256→481 and 453→459 also match exactly, including the
changed day-458 state. The two-column controls match their separate
trajectories over days 1–20, 257–258 and 454–459.

See [the full-period result](GROUNDWATER_REFRESH481_RESULT_20261109.json)
and [the daily comparison and replay evidence](GROUNDWATER_REFRESH481_EVIDENCE_20261109.zip).


## SWAP5 daily host and first refusal

The daily host starts from branch commit
`a0ce3081868a5c2137600739023f68f3c7c96c3d`. Each column has a private
donor process. The SWAP5 kernel requests one day at a time and uses its
reference-floor transaction to check water conservation and publish the
candidate state. The original donor performs Richards, drainage, macropore
exchange and all internal retries in their original order. The primary
run uses the original Andelst project files and tabulated Cauchy boundary.
A refusal leaves the committed kernel time and revision unchanged and
ends the private donor session. Its output remains available as a diagnostic.

Run the following PowerShell commands from the repository root with Python
and GNU Fortran on PATH. The recorded run used UCRT64 GNU Fortran 16.2.0 at
O2. Give each command a fresh output directory. The preparation command
checks the two nested source archive hashes. The daily host checks all
project files against the tracked original project, allowing only line
ending differences. The recorded outer archive is the local distribution
whose SHA-256 starts with `76a79498`. Its two nested source archives match
the pinned SWAP and TTUTIL sources.

```powershell
$env:PATH = 'C:\msys64\ucrt64\bin;' + $env:PATH
$archive = "$env:USERPROFILE/Downloads/SWAP_4.3.1.zip"
$ref = "$env:TEMP/hy481-reference"
$probe = "research/hybrid-water01"
python -B "$probe/run_daily_kernel.py" --reference-work $ref --prepare-archive $archive

# Build the audit object used by both fresh-process windows and test a kernel restart.
$restart = "$env:TEMP/hy481-kernel-restart"
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output $restart --restart
python -B "$probe/probe_macro_checkpoint.py" --reference-work $ref --day-return-work $restart --output "$env:TEMP/hy481-year" --year-boundary
python -B "$probe/probe_macro_checkpoint.py" --reference-work $ref --day-return-work $restart --output "$env:TEMP/hy481-dry" --dry-window
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-isolation" --days 14 --isolation
python -B "$probe/run_daily_kernel.py" --reference-work $ref --output "$env:TEMP/hy481-kernel-481" --trace-richards
```

The final command records a refusal and exits with status 1. January 15,
1998 is the first rejected day. SWAP5 retains revision 14 at its original
clock 35809. The preceding 14 published days match the independent,
unmodified donor on this compiler. The rejected day starts with exactly
the previous six stock components. Its independent water residual is
−1.9007261301e-6 cm and the kernel measures the equivalent imbalance with
its opposite sign convention. The kernel limit is 1e-6 cm. The time
integral of the 503 residuals observed on the converged `HeadCalc` path
is +1.9007497716e-6 cm. The unexplained signed remainder is 2.36e-11 cm.
The original instantaneous limits are 1e-6 cm/day per compartment and
1e-5 cm/day for the sum. This run meets those rate limits and fails the
SWAP5 day-integrated limit. The next investigation is whether the donor
can satisfy the integrated certificate while keeping its original
physical equations and registered convergence limits.

The day-2 sidecar and binary end file rehydrate a fresh donor and a fresh
SWAP5 kernel. Days 3 and 4 reproduce the continuous pressure heads,
groundwater, drainage, bottom exchange and every water stock exactly.
The fresh kernel starts a new revision sequence at the restored physical
clock. The donor-only checkpoint tests at days 365 and 453 reproduce
1,021 and 12,928 accepted steps respectively. Both compare unrounded
stock and flux ledgers and the published records. The resumed Cauchy
table copies the last original head to the fresh start date for the
legacy date validator, preserving the original terminal hold. Two dry
days independently exceed the daily SWAP5 mass limit. Both dry-window
paths reproduce those residuals exactly.

The alternating test uses two live donor processes and two committed
columns in one kernel process. Column B changes the January 2 Cauchy
entry by +0.001 cm. All 14 days in each column reproduce its separately
executed control. The 481-day unmodified donor control succeeds, but
its Windows series and the frozen reference first differ on day 3.
Published groundwater is −49.17576 cm versus −47.85008 cm and drainage
is 0.65557 cm versus 0.65540 cm on that day. The available frozen records
do not localize the cross-build difference within the day. This
comparison is separate from the exact same-build restart and isolation
results.

This daily reference-floor host returns the signed integrated and
terminal lower exchange through the existing kernel adapter. The
subdaily groundwater participant and its Cauchy interface remain
available for MODFLOW work. The day-15 refusal precedes any live
MODFLOW or full-project SWAP5 qualification.

See [the measured result](DAILY_KERNEL_RESULT_20261109.json) for exact
input and executable hashes and [the evidence archive](DAILY_KERNEL_EVIDENCE_20261109.zip)
for daily results, transaction dispositions and the original HeadCalc trace.

## Legacy restart negative control

After both commands above, run:

```sh
python research/hybrid-water01/probe_legacy_restart.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-legacy-restart
```

The fresh unmodified B0 control completes all 481 days, with the published
daily series exact to the frozen reference. The split diagnostic requests
the original binary `.end` at day 2 and reads it into a fresh process. Both
segments return normal success. Matrix, canopy, pond and snow stock match at
the boundary. The first macropore domain gains 0.04000136 cm and the remaining
domains lose 0.01962962 cm before the first resumed numerical step. The
day-3 drainage and groundwater outputs then diverge. B0's `inoutend` does
not transfer those macro fields and `Swap` calls `MacroPore(1)`/MacroInit on
the restored head. The binary legacy file cannot serve as a transparent
hybrid checkpoint. The measured stock jump is one necessary restoration
target, not a proof that these two totals are sufficient.

## Experimental macropore sidecar

```sh
python research/hybrid-water01/probe_macro_checkpoint.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-macro-restart
```

The probe preserves B0 initialization and adds a versioned, host-native
macropore stream alongside the day-2 legacy end file. It reads the stream
after MacroInit and before output or the first resumed step. Its schema is
specific to the verified GNU B0 research build. The stream includes
macropore storage, event history and module-owned calculation state. The
stored clock and grid/domain counts must match the initialized run. The
sidecar is an experimental input in a private run directory. It is not a
general restart format, nor is it paired to the end file by a content hash.

The continuous donor writes the day-2 checkpoint in place and continues to
day 4. The fresh process restores all five domain stocks and the previous
step size. The first resumed crop rotation resets the canopy reservoir even
though the legacy end file read it correctly. The sidecar preserves the
canopy stock and applies it once after that rotation, before forcing and
the first solve. This restores the wet-canopy branch and root uptake.

The two trajectories have 3,442 identical audited accepted steps over days
3 and 4, including time, step size, potential transpiration, pond and canopy
stock, and all nodal heads, water contents and temperatures at the audit
point. The daily standard series is exact. This does not compare all hidden
Fortran state or establish arbitrary-boundary or SWAP5 transaction restart.

## Andelst year boundary

Add `--year-boundary` to run an uninterrupted reference through day 367,
write its checkpoint at day 365, and replay days 366 and 367 in a fresh
process. The uninterrupted run retains the original forcing. The replay
input copy repeats the last Cauchy head on January 1. The original table
ends on December 31, and its interpolation returns that last head for
all later times. The duplicate value allows the legacy date validator to
accept a January-only window while retaining the same imposed head.

The year-only research build accepts the stored inactive crop calendar
at this checkpoint by ending the crop read when the serialized flag is
false. A calendar selected for the upcoming restart date does not imply
that crop state was present at the checkpoint. Normal daily crop setup
then activates the new crop. The probe compares unrounded daily water
ledgers and audited accepted steps. It also rejects a bad signature,
truncation and trailing bytes before normal model output.

## Isolated Cauchy head trials

```sh
python research/hybrid-water01/probe_head_transaction.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-head-transaction
```

The worker takes a constant external head in centimetres. It applies it
after tabular interpolation and before the original Cauchy condition,
including its implicit Richards contribution. Both head trials start
from one unchanged day-2 checkpoint. The original-boundary control
reproduces the historical records, while the altered trials yield
different lower fluxes. The repeated A trial after B matches in the
accepted-step audit, daily outputs, water residuals and endpoint file
digests. Only the selected A result and its day-4 checkpoint are
published to the committed directory. Positive lower flux denotes
water entering the soil column from below.

This is a process-isolated donor prototype with a fixed two-day window.
It does not exercise two resident donor states in one Fortran process,
a subdaily external window, or SWAP5 kernel transaction ownership. The selected day-4 endpoint is reopened in a fresh worker for days 5 and
6 at the same imposed head. A separate worker runs days 3 through 6 as one
window from the original checkpoint. All 3,539 audited steps of days 5
and 6, daily stocks, external fluxes and both day-6 checkpoint files match
exactly. The selected day-4 checkpoint remains byte-identical.

The experimental transaction schema S5MAC004 includes the cumulative
balance reset flag. Without this flag, restart resets the cumulative
macropore counters and their initial stock. The physical trajectory still
matches, but the next sidecar differs. The flag belongs to the checkpoint
because it determines the reporting state of the next window.

## Half-day Cauchy trials

```sh
python research/hybrid-water01/probe_subday_transaction.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-subday-transaction
```

The experimental worker caps the attempted step at the remaining time
to noon on day 5, including internal retries, and returns after the
accepted step reaches noon. It checks that the donor did not process
a day end. The existing stock and flux audit is sampled at that
endpoint for the half-day water ledger.

A clean trial at -50 cm precedes an independent rejected trial at -90 cm
and a selected repetition at -50 cm. The day-4 origin hashes remain fixed
and the clean and selected trajectories and endpoint bytes agree.
The selected result is atomically published by the research harness.
The resulting files provide endpoint comparison evidence. Reopening a
fractional endpoint, sharing one Fortran process between columns and
committing through the SWAP5 kernel API remain separate tests.

## Live handoff at noon

```sh
python research/hybrid-water01/probe_noon_handoff.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --output /tmp/hybrid-noon-handoff
```

A single donor returns to its Fortran caller at noon on day 5, keeping
the initialized state live. The caller applies the second external head
and calls the donor again. The reference uses the same noon step cap and
applies the same head inside its uninterrupted call. A fixed-head run
provides an independent check that the new head changes only the
second half of the day.

The switched head is -50 cm before noon and -90 cm afterward. The
probe requires exact audited steps, unrounded daily stocks and fluxes,
daily records and both day-6 checkpoint files. It checks the water
residual for both days and verifies that the original day-4 checkpoint
was unchanged. This qualifies re-entry into one live donor. Fractional
restart from disk, multiple donor instances within one process and
SWAP5 transaction API ownership are outside this control.

## Two resident donors in one GNU process

This Linux/glibc research probe requires the verified B0 distribution and
position-independent objects. Build the ordinary reference with the
existing B0 runner through a compiler wrapper named `gfortran` that adds
`-fPIC` to each compiler invocation. Keep that wrapper on PATH for the
commands below. The unmodified reference input and audit are the same
as in the previous probes.

```sh
python research/hybrid-water01/probe_resident_donors.py \
  --reference-work /tmp/hybrid-b0-pic --day-return-work /tmp/hybrid-day-return \
  --noon-work /tmp/hybrid-noon-handoff --output /tmp/hybrid-resident
```

The probe links one shared library and loads it into two glibc loader
namespaces. Each namespace has its own Fortran runtime and donor state.
The host calls both instances serially within a single process, switching
directories and stdout around each call. Both instances remain live at
noon and receive a different external head. They must reproduce their
separate runs exactly, including daily stocks, fluxes, the accepted-step
audit and both day-6 endpoint files. A also matches the endpoint files of
the previous standalone -50 cm control. The water ledger closes for both.

This demonstrates resident isolation by loader namespace, with serial
process-wide directory changes. It is platform specific and does not
qualify threads, fractional disk restart, or transaction ownership
through the SWAP5 kernel API.

## SWAP5 owned acceptance and next day restart

```sh
python research/hybrid-water01/probe_kernel_donor.py \
  --reference-work /tmp/hybrid-b0 --day-return-work /tmp/hybrid-day-return \
  --noon-work /tmp/hybrid-noon-handoff --output /tmp/hybrid-kernel-donor
```

The Fortran driver binds the real donor adapter to the existing SWAP5
kernel reference-floor executor. Two committed columns carry distinct
lineages and revisions. Each trial runs the Andelst solver in a fresh
worker. The executor checks the donor stock and external water ledger,
discards the first candidate for column 1 and commits four accepted
half-day candidates. The original checkpoint stays byte-identical.
The reference-floor path qualifies mass and state ownership. The normal
coupling participant's temporal controller and a MODFLOW call are outside
this test.

The afternoon trial replays the already accepted morning from the day-4
checkpoint and requires exact agreement for the full morning step audit
before accepting the afternoon ledger. This uses process isolation and
recomputation. It does not load a fractional checkpoint or use the
separate resident namespace prototype. At midnight, a fresh worker
starts from the actual selected checkpoint of each column. Day 6 must
match an independent continuous run, including audited states, the
water ledger and both endpoint files.

The donor build used by this adapter removes the local declaration that
shadows the module-owned previous wet-wall fraction in MacroIntegral.
That previous fraction is already in the macro checkpoint. The change
resolves two reporting-array discrepancies observed in otherwise exact
day-6 trajectories, while leaving the audited hydraulic behavior exact.
No canonical solver, input guard or runtime contract is modified.

## Regular coupling participant temporal check

Add `--temporal` to the kernel donor command to use the existing
groundwater SWAP participant and ordinary kernel interval executor.
The physical adapter supplies the real full window and both half
windows. For the second half it replays the first from the immutable
day-4 origin and requires exact agreement with the first-half audit.
A narrow research assessment compares maximum absolute nodal pressure
head at the endpoint against 0.05 cm. It is not a production tolerance.

At the -50 cm boundary, 0.5, 0.0625 and 0.000244140625 day windows
all close the water ledger within 1e-6 cm. The pressure head defects
are 0.328585 cm at node 77, 1.751306 cm at node 60 and 0.821688 cm
at node 57, respectively. The half-day integrated bottom exchanges
differ by about 3.03e-6 cm even though the pressure criterion fails.
The participant rejects all three with no live candidate or time,
revision or origin-checkpoint mutation. The run has zero automatic
retries so each tested window is separately observable. The test
does not establish an acceptable temporal metric or MODFLOW coupling.

## Experimental water-based temporal assessment

Use `--water-metric` with the kernel donor command. The regular
groundwater participant uses the larger of three sibling differences
in centimetres: total column water stock, the maximum water stock
difference across matrix, pond, snow, canopy and two macropore groups,
and integrated bottom exchange. The mass gate is still 1e-6 cm.
The research tolerance of 1e-4 cm is confined to this specific case,
head and origin. The original pressure diagnostic remains available
via `--temporal`.

At -50 cm, the 0.0625-day negative control is rejected because one
component differs by 5.50e-4 cm. From the unchanged origin, the 0.5-day
window is accepted: whole-column stock differs by 2.77e-6 cm, the
largest component by 5.38e-5 cm and the bottom exchange by 3.03e-6 cm.
The participant publishes the two-half candidate and converts its
bottom exchange to the signed groundwater interface flux. This
establishes an accepted normal SWAP5 participant window in the
experimental donor adapter. It does not qualify the tolerance across
other regimes, replace the pressure criterion in production, or run
MODFLOW.

## Live MODFLOW 6 corrector

Pass `--mf6 /path/to/mf6` to the kernel donor command with FloPy
installed. The tested binary is MODFLOW 6.8.0 from the F-GC44 release
archive (SHA-256 `33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e`).

The probe uses a confined, unit-area, unit-thickness cell with specific
storage 0.15 per metre and initial head -0.493 m. In each half-day
corrector the regular SWAP participant supplies the integrated bottom
exchange to a fresh MODFLOW 6 WEL trial. The host reads native heads,
WEL and STO-SS volumes, checks the native cell budget and stages the
equal-and-opposite exchange in the SWAP5 interface ledger. MODFLOW
starts each trial at the same accepted origin. This is a batch
corrector, not the prepared XMI live service.

The experimental water-metric tolerance stays at 1e-4 cm. A failed
SWAP candidate is retried halfway between the last feasible head and
the refused head. A successful but nonconverged candidate and its
staged interface entry are discarded. Publication requires head
agreement within 1e-8 m in at most fourteen correctors. The measured
run did not meet that target. Ten groundwater solves closed their
native budget, four Andelst correctors were refused, and no coupled
state or interface exchange was committed. The best head mismatch
was about 2.26e-6 m.

### Step-size and corrector sensitivity

Run the same command with `--max-step-days` set to 0.002, 0.001,
0.0005 or 0.00025. The probe sets the case's DTMAX and clips the
proposed step before weather processing, because the legacy restart
can otherwise retain an initial step above DTMAX. The worker checks
the cap again after the retry loop. For 0.002 and 0.001, repeat with
`--bracketed` to bisect between feasible opposite-sign residuals
when such a bracket exists. A sign bracket alone cannot authorize
publication. The same temporal and head criteria and 14-trial
budget apply. A refusal before the first feasible SWAP trial ends
without an MF6 solve or a commit.

All six runs ended at accepted revision zero. The best result was
3.54e-7 m with the bracket and 0.002 day cap, against 1e-8 m required.
At 0.0005 and 0.00025 days the initial trial already failed the
component-stock temporal check. The untuned two-column midnight
restart probe still reproduced both day-6 trajectories and files.

To reproduce the paired replay, use `run_worker` from
`probe_head_transaction.py` with each run's
`half/andelst_transaction_worker`, the same Andelst input and day-4
checkpoint, a fresh destination, dates 1998-01-05 through 1998-01-06,
`subday=True`, `fraction=35799.5`, `split_clock=35799.25`, the
recorded cap as `max_step_days` and each of the recorded heads in cm.
Pair each accepted trajectory record's clock and step size with the
following bottom-inward rate. Integrate by summing rate times step.
Compare the shared prefix only while both clocks and step sizes agree.

The two inputs differ by 2.90e-6 m. At the 0.002-day cap their first
149 accepted clocks and step sizes agree, but they have already
accumulated a 9.87e-5 cm difference in bottom exchange before the
grids separate. The result rules out different accepted time grids
as the sole explanation. It does not identify the upstream state
transition responsible for the growth. The donor's Cauchy flux uses
the modelled water table at the beginning of a step, and SoilWater(3)
updates that water table after each accepted solve. This feedback and
the matrix/macropore iterations are the next targeted comparison.

### One live volume handoff at the initial groundwater head

Add `--origin-predictor` to the MF6 command with `--max-step-days 0.002`.
The existing donor and SWAP5 participant perform one half-day trial
with the initial groundwater head (-0.493 m) as the imposed constant
head. The temporal gate remains active before any MF6 solve. After
the equal-and-opposite volume handoff the existing head and budget
criteria determine whether publication is possible. A failed head
check discards both trial entries and leaves the accepted origin intact.

The day-four checkpoint was rebuilt from the pinned original SWAP
archive with GNU Fortran 13.3.0 and reproduced the recorded hashes.
The native MODFLOW 6.8.0 run received -0.00118024830 m3 and closed the
one-cell budget to 1.42e-14 m3. All three SWAP temporal defects were
below 1e-4 cm. MODFLOW ended at -0.500868322 m, a head residual of
7.868 mm. The origin predictor therefore did not pass the strict head
criterion or commit. See `ORIGIN_PREDICTOR_RESULT.json`.
