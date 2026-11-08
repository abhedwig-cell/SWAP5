# HYBRID-WATER01 donor day boundary

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
