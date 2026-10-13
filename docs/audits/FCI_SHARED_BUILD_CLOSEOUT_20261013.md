# Shared root/sensor build qualification and Richards audit (13 October 2026)

Status: **qualified isolated shared-build scope; local F-CI preserved; canonical admission pending.** The September revision comparison is **FAIL**, independently of the shared-build qualification. No production physics, numerical tolerance, incumbent driver, historical evidence or default F-CI runner is changed.

This is the current disposition for PR #1218. Earlier runtime-cost, decision-checkpoint and duplicate-callsite audit documents describe historical investigation stages. The proposed duplicate crop-guard edit was restored: the default F-CI runner is byte-identical to canonical. This work does not admit controller consolidation, cross-invocation object caching or test-result reuse.

## Scope and implementation

The original allocated root/restart and sensor/restart gates independently select the same 176-source module closure. Full source discovery has 402 candidates, including the two explicit fixture providers. The shared runner compiles that closure and legacy headcalc once per O0/O2, then compiles, links and runs both unchanged drivers independently. Private driver directories prevent module leakage. Common objects/modules are hash-checked before and after each driver. Fresh build directories are removed after every invocation.

The identity helper rejects duplicate providers, unresolved modules, cycles, unequal root/sensor closures, source symlinks, unmodeled includes/preprocessing, implicit module pollution and input drift. Module order was compared with both incumbent selectors. All original flags, Full Richards, mass accounting, rejected-trial isolation, restart and assertions remain present; O0/O2 output comparison is exact.

The C observer records actual compile/link/native processes with monotonic wall time and wait4 CPU time. Its four real ELF copies are byte-identical between original and shared arms in every round. No speed improvement is attributed to the model programs.

## Actual build A/B

GNU Fortran 13.3.0, same Xeon Platinum 8573C host, OMP_NUM_THREADS=1. Three alternating rounds on `bf239429ed114e3638800bf9c99e16745d8e31fa`; stricter guard postimage additionally executed without instrumentation on `38c97e54553f3f0e0fb2be08baa3f6fe8f46ada9`.

| Round | Execution order | Original pair wall (s) | Shared wall (s) | Saved (s) | Saved (%) |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | root → sensor → combined | 867.402 | 539.695 | 327.707 | 37.78 |
| 2 | combined → sensor → root | 874.873 | 529.208 | 345.665 | 39.51 |
| 3 | root → sensor → combined | 781.539 | 499.225 | 282.314 | 36.12 |
| Uninstrumented control | root → sensor → shared | 896.177 | 534.294 | 361.883 | 40.38 |

Every round removes **354 of 712 compilations (49.72%)**, retaining four links and four native scientific executions. Mean measured gate saving across the primary three rounds is **318.562 seconds**; median is 327.707 seconds. Summed compiler wall time averages 515.942 → 249.811 seconds; compiler CPU averages **508.396 → 242.507 seconds (52.30% less)**.

| Round | Original compile/native CPU (s) | Shared compile/native CPU (s) | Original total CPU (s) | Shared total CPU (s) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 519.598 / 321.127 | 245.437 / 278.311 | 859.105 | 537.672 |
| 2 | 541.763 / 305.089 | 250.545 / 251.273 | 869.827 | 513.292 |
| 3 | 463.827 / 300.118 | 231.539 / 254.629 | 780.198 | 497.922 |

The primary nine-arm comparison took 4105.522 seconds of calendar time. First root arm overlapped an obsolete diagnostic build that was terminated; rounds 2/3 had no concurrent heavy audit work. Documentation rendering overlapped part of the extra uninstrumented control. Host is shared. These limitations are retained; the measured paired-gate saving is not a portable guarantee or a whole-F-CI estimate. Native timing varies despite identical ELFs, so native acceleration is not claimed.

Scientific hashes in every original/shared and O0/O2 comparison:

- root: `0f52a93c461b70111f58c07ddfd926858aad3cccec02d2c26d10ccb1d3c5ed6f`
- sensor: `8b588e92eee50b2fe1df745145e0f0743a305f8617091f8169cc80789c3e627e`

## Full Richards revision investigation

Actual 50-node, 100-cm medium-soil trajectories: uniform initial h=-75 cm; sinusoidal infiltration 0.1±0.08 cm/day, bottom outflow 0.05 cm/day; 0.005-day maximum steps, halving retries, minimum 1e-6 day. Identical numerical settings, 1e-12 hard independent mass gate and O2 runtime-checking flags on all revisions. Short horizon 0.1 day; long horizon 30 days. Each revision/horizon ran five times in alternating order. Complete heads, theta, pond, groundwater level, returned boundary fluxes, dt and mass are retained per step. Timing surrounds actual solve calls, separate from trajectory output.

Current diagnostic head: `ffb476607ad4859b3dca6cac991a135f642e8f15`; recent baseline: `a3859c89eaf97256a6330bb9f6370013c4a9e2f2`; September baseline: `50346642bd565f79134ea17d5462e544b354998c`. Every full source checkout, selected source, generated fixture and compiler command is identified. The September contract lacks the constitutive-work counter; only that diagnostic assignment is adapted, recorded as unavailable/UNKNOWN, never zero.

| Horizon | Revision | Native wall median (s) | Solve CPU median (s) | Physical comparison with current |
| --- | --- | ---: | ---: | --- |
| 0.1 day | earlier | 0.009650 | 0.002327 | FAIL |
| 0.1 day | recent | 0.008978 | 0.002084 | exact PASS |
| 0.1 day | current | 0.008168 | 0.001617 | exact PASS |
| 30 day | earlier | 1.611851 | 0.731259 | FAIL |
| 30 day | recent | 1.367023 | 0.490888 | exact PASS |
| 30 day | current | 1.413860 | 0.512818 | exact PASS |

All runs converged with zero retries: short 20 accepted steps and 61 nonlinear/Jacobian/linear operations; long 6000 steps and 18001 operations. Current/recent constitutive counts are 81 / 24001. Long maximum independent mass error: current/recent 4.065e-14 cm, September 4.085e-14 cm, all below the predeclared 1e-12 gate. Passing individual mass gates does not turn a different trajectory into an equivalent one.

**September strict equivalence = FAIL on all ten comparisons.** First difference occurs at step 1; long maximum head difference is 1.393e-12 cm, theta difference 1.332e-15, and per-step mass difference 5.684e-14 cm. Pond, groundwater and boundary fluxes match. These magnitudes describe the failure; no tolerance is introduced to erase it. A qualified equal-output performance ratio against September is **UNKNOWN**. The underlying production source changed before this audit, not in this PR.

Current and 11 October have identical generated drivers and all **17 selected production sources**, exact physical trajectories and identical operation counts. Initial long medians differ by +4.47% solve CPU, with large overlapping ranges (current 0.442–0.704 s, recent 0.431–0.561 s). Short millisecond measurements include an outlier and are insufficient for a small performance claim.

A further **20 alternating pairs on fixed CPU 8** executed the actual existing current/recent binaries afresh. Binary and runtime-library hashes are checked before/after; all 40 complete raw scientific outputs match exactly. Solve CPU medians: recent **0.368277 s**, current **0.363261 s**. Paired median current/recent ratio 0.9713; descriptive paired bootstrap interval 0.9460–1.0067 (seed 1218, 10000 resamples). This interval assumes exchangeable pairs on this shared host; it is not a portable error bound. Direction changes versus the initial sample, so there is **no demonstrated regression or qualified solver speedup versus 11 October in this bounded fixture**. No inference is made about complete crop/coupling/F-KT application runtime.

Both current and September actually ran the gprof builds; stdout matched their own unprofiled physical/work outputs exactly. Raw profiles and gmon files are preserved. Only 30 / 20 samples were collected; formatted output and generated finalization/bookkeeping appear alongside headcalc/provider work. These coarse samples do not support precise hotspot percentages or a production solver edit. Direct solve timing avoids counting trace output as solver work.

SWAP 4.3.1/B1.11: all **63 source members** byte-verified against frozen manifest `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`; archive SHA256 `18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c`. Sources are restored and available. A matched historical runtime has not been executed: **UNKNOWN**. No new upload is needed or requested.

## Preservation, negative controls and identities

The unmodified full moving F-CI gate ran locally with resume OFF and exited 0 on `38c97e54553f3f0e0fb2be08baa3f6fe8f46ada9`: wall **5383.975 s**, user CPU 4810.996 s, system CPU 539.031 s. Original stdout/stderr and 27 available child logs are preserved. Terminal marker: `FCI_CANONICAL_LINEAGE_AWARE_GATE PASS`. This is preservation evidence, not a full-F-CI speed A/B.

Actual negative controls reject a duplicate source provider, fixture drift, real compiler failure before science, implicit module pollution, includes and source symlinks. Unit controls also reject missing modules, cycles, unequal output identities and altered ELF identities. Sixteen tooling tests pass, C observer compiles with warnings as errors, shell syntax and diagnostic APIs pass. Earlier failed development/unit attempts are retained separately and do not qualify the final candidate. The deterministic variable-output test is corrected; no numerical test was weakened.

Qualification dependency surface remains:

- production source tree `98440388d8640d5c62ca03f9a193632b3df41ecd`;
- reference tree `c680d7a93aabfd1321c2bcee872aa0361b73fcb8`;
- default F-CI runner blob `6f44e3163cbfe28ac85539dad5416c156604879e`;
- both unchanged incumbent drivers/runners, fixture providers, shared build helper/runner, toolchain and flags.

Later changes are diagnostic or evidence-only. Owner/F-CI evidence is retained only for these unchanged scientific surfaces; it is not a claim that a different production head passed. No migration capability is added or removed by this tooling admission.

## Reproduction and evidence

Use a clean complete checkout and the recorded compiler/environment. Each command creates a new evidence destination:

```bash
OMP_NUM_THREADS=1 python3 tests/performance/compare_mc_irr01_shared_build.py --output-dir /tmp/shared-ab-new --repeat 3 --instrument
OMP_NUM_THREADS=1 python3 tests/performance/compare_mc_irr01_shared_build.py --output-dir /tmp/shared-uninstrumented-new --repeat 1
FCI_RESUME_MODE=OFF OMP_NUM_THREADS=1 bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh
OMP_NUM_THREADS=1 python3 tools/performance/run_richards_revision_audit.py --output-dir /tmp/richards-new --repeat 5
OMP_NUM_THREADS=1 python3 tools/performance/refine_richards_same_core.py --source-dir /tmp/richards-new --output-dir /tmp/richards-core-new --repeat 20 --core 8
```

The default September comparison correctly returns 1 on strict output mismatch and retains both profiling results. A new checkout path can change absolute compiler diagnostic strings and ELF identity; physical comparison remains exact. Choose an allowed CPU and record it on other hosts.

The usable isolated faster route is `bash tests/performance/run_mc_irr01_shared_build_experiment.sh`. Its experimental filename denotes no default F-CI replacement; the current source/fixture/toolchain scope is qualified by the evidence above. Requalify if its dependency surface changes.

Machine-readable authorities and raw recoverable archives:

- `integration/audits/FCI_SHARED_BUILD_THREE_ROUNDS_20261013.json`: primary alternating A/B, raw compiler/native logs, inputs and executable hashes.
- `integration/audits/FCI_SHARED_BUILD_QUALIFICATION_20261013.json`: uninstrumented comparison, negative controls and full F-CI logs.
- `integration/audits/RICHARDS_REVISION_PROFILE_20261013.json`: all revision trajectories, profiling logs, same-core comparisons, build inputs and compiled profiling executables. Concatenate numbered base64 part files, decode and extract the xz tar; verify the declared SHA256 first.

Admission scope is isolated test-build tooling and reproducible diagnostics. The default F-CI route, production solver, numerical tolerances and immutable historical evidence remain unchanged. Broad solver-regression, legacy-runtime and whole-F-CI speed claims remain explicitly outside the qualified evidence.
