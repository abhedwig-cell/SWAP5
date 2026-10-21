# PERF01 temporal proposal diagnostic recovery

Status: reconstruction and fresh execution, not production admission.
Scientific source baseline: `9a3a15197adbf37dba340f4f9acbbb44fe76a989`.

The original unpushed temporal-study commits and raw evidence were lost from
the transient workspace after the publication review rejected the push. Their
reported timings cannot be reconstructed as raw observations from conversation
text. This recovery rebuilds the diagnostic script and generates a new evidence
set. It does not label new measurements as the lost originals.

The admitted exact PERF01 optimization remains unchanged. No production module,
default policy, physical formula, tolerance or restart schema is modified.
The existing default-OFF `retain_accepted_step_proposal` is enabled only in a
generated experimental main. An optional generated runtime variant targets the
exact requested endpoint before solving when the proposal was already within
the existing progress tolerance. No already-computed trace is relabelled and no
strict chemical endpoint check is relaxed. Trial isolation, hard mass, external
atomicity and restart invariants remain the governing boundaries.

Selected experiments: eight 0.001-day windows for positive pond 4/32/256-cell
columns, a 32-cell dry column and a discontinuous rainfall case. Both policies
are compared at temporal tolerances 1e-6, 2.5e-7, 6.25e-8 and 1e-9 at O2.
O0 uses 1e-6 and 2.5e-7 for bounded state/restart preservation. Finer references
are finite-tolerance convergence diagnostics, not exact solutions or newly
accepted tolerances. Fresh-process split-window restart must reproduce final
state/endpoint/restart bytes and resumed budget and trajectory rows exactly.
The default-OFF observer must reproduce the uninstrumented application files.
Wet/pulse timing uses three interleaved repeats, core CPU timed only around the
real joint interval call. Failed/censored native runs stay in the record.

The unchanged 178-provider build is reused only after checking all source and
executable hashes; generated main/runtime and object hashes are retained. O0
and O2 are separate builds. No full moving F-CI or highest low-air stress test
is selected for diagnostic-only files. Individual native runs have a 120-second
cap. No seasonal, live-crop, heat/BBC or regional throughput claim follows from
these short prescribed-sink columns.

## Fresh results, 21 October 2026

**Diagnostic complete; no general activation.** The final isolated set contains
170 native model executions, including two deliberately reproduced native
failures. The expected failures remain failures, never PASS observations.
GNU Fortran 13.3.0, O2 production and checked O0, same scientific source baseline
as above. These observations replace the unavailable raw temporal-study data;
they are not a recovery of the earlier timing samples.

| Case | Default policy core CPU s | Proposal core CPU s | Default / proposal | Attempts default / proposal | Solver rejections default / proposal |
| --- | ---: | ---: | ---: | --- | --- |
| Pond 4 cells | 0.156610 | 0.021688 | 7.22 | 6784 / 835 | 0 / 0 |
| Pond 32 cells | 0.306163 | 0.048707 | 6.29 | 3705 / 541 | 0 / 0 |
| Pond 256 cells | 0.344271 | 0.095675 | 3.60 | 624 / 160 | 0 / 0 |
| Rain pulse 4 cells | 0.146423 | 0.021543 | 6.80 | 6784 / 835 | 0 / 0 |
| Dry 32 cells, diagnostic endpoint correction | 0.055526 | 0.125912 | 0.44 | 673 / 1646 | 278 / 808 |

Medians of three paired repeats, temporal tolerance 1e-6. Full CPU ranges, wall
times and per-window counters are in each `CONTROL.json`/`work.csv`. Timing
excludes diagnostic snapshots and output outside the joint interval call, input
generation and compilation. Ratios compare two SWAP5 policies after the admitted
PERF01 trace optimization, not SWAP5 versus SWAP4.3.1. They must not be multiplied
by the earlier PERF01 speedups or extrapolated to seasonal HRUs.

The corrected dry proposal route is 2.27 times slower. Temporal rejections fall
from 242 to 19, but solver rejections increase from 278 to 808, accepted internal
transactions from 153 to 819, and HeadCalc calls from 1668 to 3445. The existing
proposal rule is therefore not a generally demonstrated performance improvement.

## Endpoint failure and the isolated correction

The unchanged optional route rejects dry32's first joint interval at O0 and O2:
`JOINT_CHEMICAL_REJECTED`, `MATRIX_INVALID`, zero completed chemical substeps.
The water trace ends at `9.9999999999999915e-4` rather than `1e-3` day, a gap of
`8.6736173798840355e-19` day. Water completion permits the incumbent progress
tolerance; `consume_accepted_pond_trace` requires an exactly matching endpoint.
This is a completion/consumer contract mismatch, not evidence of physical water
loss. Both external committed clocks remain exactly zero after rejection.

`--snap-proposal-endpoint` compiles a generated diagnostic runtime which chooses
the exact requested endpoint before solving when the optional proposed target
is already within that progress tolerance. No calculated trace is relabelled,
acceptance test disabled, or chemical endpoint assertion relaxed. It resolves
this observed failure, but does not remove the dry-profile cost regression. The
production module is never edited. Its default-OFF path remains unchanged.

## Accuracy, inventories and restart

All reporting-window heads, theta and concentrations, cumulative water/solute
terms and final inventories are compared to both finite 1e-9 references. For
the dry refinement the diagnostic endpoint correction is explicitly selected.
In the 4-cell case, maximum head errors against the finer proposal reference at
tolerance 1e-6 are 4.27e-4 cm for the default route and 5.41e-4 cm for the proposal.
Tightening the proposal tolerance to 2.5e-7 reduces that error to 2.62e-4 cm.
Corresponding 32/256-cell proposal errors are 1.68e-4 and 4.60e-5 cm, below default
1e-6 errors 2.80e-4 and 8.12e-5 cm. This bounded convergence study establishes no
exact Richards solution, global error bound or general production admission.

Every completed case compares the default-OFF observer at 1e-6 to all four
uninstrumented physical files. Fresh-process restart after window four matches
the continuous final state, endpoint and restart bytes and all resumed budget
and trajectory rows. All five corrected cases pass both-policy restart at O0
and O2. Sixteen matched wet/pulse runs at 1e-6/2.5e-7 retain exactly the same
physical files and numerical work with the diagnostic endpoint variant.
Default-tolerance O0/O2 work counters also agree for every policy/case.

Maximum outer-window residuals in the completed isolated set are 1.13e-12 cm
water and 1.42e-11 mg/cm2 solute, within the unchanged application assertions.
O0's 1e-9 series was not selected; no O0 fine-reference claim is made. Default
activation, general restart admission, live seasonal crop/heat/BBC execution and
regional performance remain outside this study.

## Evidence and reproduction

The fresh verified capsule is
`integration/performance/evidence/perf01-temporal-20261021/INDEX.json`:
1417 members, 256592 decoded bytes, with a SHA256-bound member inventory.
Concatenate its base64 parts, decode and read the xz tar. It contains all inputs,
generated main/runtime sources, compiler/build/source hashes, per-process raw
files, repeat timings, work counters, full window trajectories, restart files,
both native failures and the sequential execution receipt. Native objects and
executables are regenerated rather than embedded.

Earlier reconstruction attempts caught incomplete diagnostic trajectory files
and were rejected by the alignment/inventory guard. They are preserved separately
in `perf01-temporal-rejected-io-20261021/INDEX.json`, not selected as qualification
or timing data. The final 170-execution set ran sequentially in an isolated
temporary directory and was packaged and verified after native execution ended.
The physical production assertions were not changed to overcome this I/O issue.

```bash
export FC=gfortran
python tools/solute/build_column.py --optimization O2 --build-profile production --output /tmp/perf01-study/build-O2
python tools/performance/run_perf01_temporal_recovery.py --results /tmp/perf01-study --capsule /tmp/perf01-study-capsule
```

The runner builds checked O0 separately, performs the studies sequentially, and
recognizes only the explicitly validated strict-endpoint reproducer as an
expected native failure. Every other native failure remains blocking. Use the
individual study CLI to reproduce smaller subsets; no extra solver is selected.
The next scientific work is solver-aware proposal control with an exact endpoint
contract and its owning accuracy/restart/admission qualification. Favorable wet
timings alone do not authorize new production activation.
