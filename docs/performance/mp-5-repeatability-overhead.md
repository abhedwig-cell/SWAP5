# MP-5 MP-B01 repeatability and observer-overhead qualification

**Workstream:** MP  
**Status:** QUALIFIED FOR SHADOW MEASUREMENT MECHANICS; production performance baseline still pending  
**Baseline:** `da99f14490ca81737ae9ab070d77a2197e6799ba`  
**Affected invariants:** 3, 5, 7, 13, 16, 23, 25, 26, 30

## Purpose

MP-5 was intended to make the first difficult-column workload executable if a qualified B12 fixture had become available. It had not. The only versioned B12 evidence remained the hydraulic Staringreeks 2018 row locked by MP-4, so MP did not invent the missing profile, forcing, boundaries or process configuration.

MP-5 therefore follows the explicit MP-4 fallback path and qualifies the repeatability and measurement overhead of `MP-B01-HUPSEL-SINGLE` before any performance conclusions are drawn from the observer.

The objectives are:

1. rebuild the B0 shadow fixture from the exact source archive with the current byte-safe transformation;
2. verify measurement `off` and `on` remain physically transparent for the selected outputs;
3. measure run-to-run noise with an interleaved paired protocol;
4. determine whether the coarse observer overhead is resolvable above that noise;
5. version the raw samples and deterministic summary tooling.

## Prerequisite tooling defect found and corrected

Re-executing the byte-safe shadow preparation exposed a regression introduced when MP-3A changed source decoding from lossy UTF-8 replacement to reversible Latin-1.

The official `swap_main.f90` uses CRLF line endings. `instrument_swap_main()` still searched only LF anchors. Therefore `prepare_shadow_source()` could fail on the real B0 archive even though the synthetic LF-only unit test passed.

MP-5 corrects the injection code so it detects and preserves the source newline convention. Regression tests now cover LF observer injection, CRLF observer injection, `prepare_shadow_source()` on a synthetic 63-file archive with CRLF `swap_main.f90`, and preservation of a non-UTF-8 byte through the Latin-1 shadow transformation.

The actual supplied B0 archive was then prepared successfully with the corrected tool.

This is a performance-tooling defect only. It is not a SWAP 4.3.1 physics defect and does not enter the B0/B1 legacy correction chain.

## Clean shadow rebuild

For the definitive MP-5 experiment, both variants were rebuilt cleanly from the newly prepared source trees rather than selectively relinking the earlier MP-3 object tree.

Common build characteristics:

- exact B0 source archive SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`;
- compiler: GNU Fortran 14.2.0;
- SWAP compilation: `-O2 -ffree-line-length-none -fallow-argument-mismatch` plus the TTUTIL module include path;
- link optimization: `-O2`;
- known Intel conditionals resolved for Linux standalone;
- GNU TTUTIL library rebuilt from the supplied distribution and reused from MP-3 tooling.

Executable identities for this evidence set are:

| Variant | SHA-256 |
| --- | --- |
| clean uninstrumented shadow | `adc8f69a5de517261c6e4e703a5cecd8eebfb887d702aa146d4aa6c8aac9d443` |
| clean instrumented shadow | `454649f5f6488212eed422407f34153f7590271b125867803b3daf111bd646ee` |

These executables are experimental GNU shadow builds. Neither is a replacement B0 executable or a SWAP5 production build.

## Case and physical transparency

The experiment uses the supplied Hupsel case over 2002-01-01 through 2004-12-31, with the same disposable `SWCSV=0` adjustment used in MP-3A because of the GNU shadow CSV limitation.

Three variants are distinguished:

- `base`: clean uninstrumented shadow executable;
- `off`: clean instrumented executable with `SWAP5_MP_MEASURE=0`;
- `on`: the exact same instrumented executable with `SWAP5_MP_MEASURE=1`.

All 54 measured runs produced the same normalized physical-output hashes:

| Output | SHA-256 |
| --- | --- |
| `result.bal` | `8225c618e5a36243ab1a48f689c3ef09f28985bbdf501d38c6fdfb84f6fa7e7e` |
| `result.blc` | `d013c4ecc7bbdde76b5f0e03483dbc9d15e6b64c936eebe50a3e2624d5c8b66a` |

Thus the current byte-safe clean shadow build confirms the selected MP-3A physical-transparency result for both measurement states.

## Repeatability protocol

The host exposed five logical AMD EPYC 9V74 CPUs and was not dedicated. CPU affinity was not pinned. Consequently this experiment is explicitly a measurement-mechanics qualification, not a hardware performance baseline.

One warm-up run was made for each variant. Eighteen measured cycles followed. Within successive cycles the order rotates:

```text
base, off, on
off, on, base
on, base, off
```

The rotation repeats six times, producing 18 samples per variant and 54 measured process runs. External wall time uses `time.perf_counter_ns` around the complete process.

The primary observer-cost comparison is paired `on` versus `off` within each cycle because those two runs use the same executable and differ only by the measurement environment flag. `base` versus `off` is retained only as a diagnostic for executable-layout/build effects.

Raw samples are stored in `benchmarks/performance/evidence/mp-b01-shadow-repeatability.samples.jsonl`. `tools/performance/mp_repeatability.py` validates physical-output hashes and calculates the deterministic summary.

## Results

Wall-time distributions were:

| Variant | n | Mean s | Median s | CV |
| --- | ---: | ---: | ---: | ---: |
| `base` | 18 | 0.95255 | 0.95057 | 2.23% |
| `off` | 18 | 0.94925 | 0.94499 | 2.60% |
| `on` | 18 | 0.95034 | 0.95147 | 2.42% |

For paired `on/off - 1`:

- mean: **+0.17%**;
- median: **+0.35%**;
- standard deviation: **3.30%**;
- two-standard-error scale: **1.56%**.

The absolute paired mean is smaller than the two-standard-error scale. MP-5 therefore classifies the observer overhead as **not resolved above measurement noise** on this host.

This does not mean that observer overhead is zero. It means this experiment cannot distinguish the measured +0.17% mean from the surrounding run-to-run variation. A percentage smaller than the current noise floor must not be presented as a qualified production cost.

The diagnostic `off/base - 1` comparison is also unresolved: paired mean -0.32%, median -0.27%, two-standard-error scale 1.20%. That demonstrates why the same-binary `off/on` comparison and paired execution order are required.

## Internal observer timing

The enabled observer measured only the top-level dynamic SWAP call. Across 18 samples, mean internal dynamic time was 0.94135 s, median 0.94041 s and CV 2.44%.

This remains a coarse shadow timing. It does not expose constitutive, residual, Jacobian, linear-solve, Newton-control or retry phases.

## Qualification decision

MP-5 establishes that the current byte-safe shadow preparation works on the real B0 source archive, CRLF and non-UTF-8 source handling are regression-tested, a clean current shadow rebuild preserves selected physical outputs with measurement off/on, raw paired timing evidence is versioned and machine-summarizable, and the top-level observer cost is below the resolving power of this 18-cycle non-dedicated-host experiment.

MP-5 does **not** establish a zero-cost observer, a SWAP5 production instrumentation overhead, a CPU reference baseline suitable for hardware comparison, deterministic process wall time, B12 difficult-column cost, MultiSWAP batch scaling, normal/relaxed/fallback costs or GPU suitability.

## Integration boundary

No production kernel, solver, runtime or coupler interface changes in MP-5.

- VQ still owns physical and mass-balance acceptance.
- TX/HY still need to expose a stable production observation seam.
- RT still owns future template, worker and batch identities.
- MP owns the repeatability protocol, raw performance evidence and statistical resolution statement.

## Next safe step

MP-6 can improve the CPU measurement baseline by adding a controlled-host protocol: explicit CPU affinity, host/load metadata, repeated-run noise gates and a minimum detectable overhead criterion. This can be prepared independently of TX/HY.

If a VQ-qualified B12 fixture becomes available before then, MP-B04 can instead be promoted from `parameter-locked` to an executable qualification candidate, but only through an explicit catalog change and VQ gate.
