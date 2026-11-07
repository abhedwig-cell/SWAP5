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
a subdaily external window, or SWAP5 kernel transaction ownership. The
selected endpoint is written and checked by hash. Reopening that new
endpoint for day 5 is outside the exercised window.
