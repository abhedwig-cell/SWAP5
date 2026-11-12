# Intact original macropore block: short execution restored, restart still open

Research implementation, not admitted. Base canonical:
`a22754decc0ec4e69304d1495c48bae7cdcdabec`. This follows the rejected paired
residual/derivative candidate in PR1652. No default builder activates this policy.

The original nonlinear/macropore block is retained, including MACROPORE task2
rate calculation, task3 Jacobian calculation, `flunsatok` cache control,
backtracking, convergence tests and MACROSTATE. Added research calendar windows
for macro refresh and lateral pond feedback are removed. Existing daily mass
retry is enabled from day1. Original forcing, equations and tolerances remain
unchanged. This is a candidate replacement of a research policy, not a claim that
the original frozen-rate method is scientifically qualified over481 days.

## Results and decision

The original block completes the previously failing first four days. Final
Windows fresh execution takes3.286s with the O0 day-owner kernel and3.007s with
O2; own2→4 takes2.446s/2.396s. **Original donor physics objects are O2 in both
cases**, matching the preserved provider; this is not an all-donor-O0 claim.
Every day is accepted under the unchanged1e-6cm guard, maximum independent
residual5.965353207744765e-7cm. These short timings do not establish whole-model
or accuracy-matched performance. No full model or new reference run was started.

All physical receipts in own2→4 and the complete native `result.end` are exact.
The initial stronger auxiliary comparison fails: original formatS5MAC003 differs
by656bytes on3 and96bytes on4. A real compiler I/O-length field map identifies
cumulative reset bookkeeping and two integrated wet macropore wall fractions.

The existing checkpoint omitted the original reset flags. Restoring macro
stocks while retaining cold-start `flzerocumu`/`flzerointr` resets cumulative
bookkeeping. Saving those flags eliminates the cumulative-field mismatch.
Original HeadCalc's local SAVE `NStep` and `iwarn` counters are also explicit
worker-owned restart context, retaining exactly the original calculation and
increment order. They are zero in this prefix: their relocation is **not** an
explanation of the remaining wall-integral difference.

New native formatS5MAC005 appends both reset flags and both counters. The exact
old-format reader now refuses other magic; no old checkpoint is rebound or
filled with guessed context. The wrapper's unchanged complete source/build
binding also prevents foreign checkpoint adoption. Retained v3/v4/v5 generated
sources and build identities keep the successive experiments distinct.

Final O0/O2 own2→4 has fully byte-exact `macro.bin` on4, but559bytes differ on3,
confined to `IAvFrMpWlWtDm1` and `IAvFrMpWlWtDm2`. External discard preserves the
accepted origin and rejects the discarded proposal. Repeating its day3 proposal
reproduces the complete receipt and both native payloads exactly. A subsequent
cold recovery3→4 still differs by698bytes in the same two wall-integral arrays;
all physical receipts and `result.end` remain exact. **The complete auxiliary
restart assertion remains FAIL.** These integrals also supply PEARL/ANIMO;
they are not waived, zeroed, rounded or declared harmless. External discard
does not qualify numerical rejected-timestep rollback; this prefix has zero
mass-guard retries.

The next acceptance target is full native equality on2→3 and independently
recovered3→4, using the original wall-fraction integration history and timestep
context. Do not add dates, repeat the failed refresh variants, widen time caps,
or start481 days to diagnose these two arrays. Late-event/Linux/full-period
qualification remains gated by this concrete short restart failure. Scientific
Grass/Hupsel/Andelst dispositions and existing admitted application profiles are
unchanged.

## Exact evidence and reproduction

Owner: `integration/f-ci/ORIGINAL_MACRO_BLOCK_20261112.json`.
Machine result: `ORIGINAL_MACRO_BLOCK_RESULT_20261112.json`.
Evidence: `original-macro-block-evidence.zip`; SHA256 in the owner record.
It contains raw success/failure logs, native checkpoints, source-bound build and
link commands, generated Fortran, compiler-derived field layout, the final
executed builder and member hashes. Failed assertions remain visible.
The field map covers the unchanged first15,322,608bytes; appended context is
compared separately. Only corresponding same-format payloads are compared.

Extract preserved `hybrid-hupsel-windows-20261111.tar.xz` (SHA256
678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1) to `$base`.
Use its exact MSYS GNU16.2 compiler/provider. From the repo root, create a fresh
parent `$probe`, put `C:\msys64\ucrt64\bin` on PATH, then:

```powershell
$env:PYTHONPATH = "$PWD/app/hybrid_water"
python -B -c "from original_macro_policy import build_bundle; build_bundle(r'$base/andelst-O2', r'$base/reference', r'$probe/build')"
python -B research/hybrid-water01/probe_original_macro_block.py --bundle "$probe/build" --reference "$base/reference" --output "$probe/fresh" --cap-seconds 20
python -B research/hybrid-water01/probe_original_macro_block.py --bundle "$probe/build" --reference "$base/reference" --checkpoint "$probe/fresh/accepted-column-1-day-2.zip" --output "$probe/restart" --cap-seconds 20
python -B research/hybrid-water01/probe_original_macro_discard.py --bundle "$probe/build" --reference "$base/reference" --checkpoint "$probe/fresh/accepted-column-1-day-2.zip" --control "$probe/fresh/accepted-column-1-day-4.zip" --output "$probe/discard"
```

Use `andelst-O0` in a distinct build/output for the kernel-O0 prefix/restart.
The final command is expected to return2 at the complete auxiliary assertion;
do not report it as PASS. Workers are killed/reaped at the20s cap. Functional
coverage stays the three previously admitted applications. Development yield
is a four-day terminating replacement and a narrowed, source-bound restart
failure with the cumulative bookkeeping cause repaired, not full qualification.
