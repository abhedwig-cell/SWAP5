# MP-6 controlled-host CPU baseline protocol

**Workstream:** MP  
**Status:** PARTIAL, protocol exercised; 1% CPU baseline rejected on current host  
**Baseline:** `dd2e0d1b9ecac671e8b02f703c7b3b8510fe36e0`  
**Affected invariants:** 3, 5, 6, 13, 16, 23, 24, 25, 26, 30

## Purpose

MP-5 showed that the coarse observer effect was smaller than run-to-run wall-time noise. MP-6 therefore defines a controlled CPU-baseline protocol before any MultiSWAP scaling or GPU claim is made.

The protocol separates three questions:

1. did the benchmark produce the same physical result;
2. is the measurement environment repeatable enough for the predeclared resolution target;
3. only then, is an observed performance difference resolved above that measurement floor.

A failed repeatability gate rejects the performance claim, not the physical model.

## Clock and metric semantics

MP-6 makes timing semantics explicit.

- `child_cpu_seconds` is the primary CPU metric for the shadow executable. It is the delta of child-process user plus system CPU time reported by the operating system.
- `wall_elapsed_seconds` is a secondary monotonic elapsed metric around the complete process.
- MP-2 interval timings use `perf_counter_ns` and are therefore monotonic elapsed timings, not CPU time.

The MP aggregator is corrected accordingly: sums of MP interval timings are named elapsed time, and worker totals are explicitly attributed elapsed time. They must not be interpreted as worker CPU utilization.

## Predeclared resolution rule

For paired relative deltas `d_i`, MP-6 defines the operational measurement floor as:

```text
minimum_detectable_relative_effect = k * s(d) / sqrt(n)
```

where this MP-6 plan uses `k = 2`.

This is an engineering repeatability rule, not a claim of a formal power-analysis confidence interval.

Two separate gates apply:

```text
target-resolution qualified:
    minimum_detectable_relative_effect <= predeclared target

observed effect resolved:
    abs(mean paired delta) > minimum_detectable_relative_effect
```

If an effect is not resolved, the conclusion is **not resolved**, never "zero overhead".

Timing outliers may not be deleted merely because they are inconvenient. A pair may only be invalidated by a predeclared objective execution failure such as wrong physical output, wrong affinity or unexpected process completion.

## Pair count chosen before the run

MP-5 measured a paired wall-time standard deviation of:

```text
0.03303993093797261
```

For a predeclared 1% resolution target and `k=2`, the pilot implies:

```text
ceil((2 * 0.03303993093797261 / 0.01)^2) = 44 pairs
```

MP-6 therefore fixed 44 pairs before examining the MP-6 effect estimate.

The versioned plan is `benchmarks/performance/cpu-baseline-protocol.json`.

## Execution controls

The MP-B01 exercise used:

- the same clean instrumented GNU shadow executable for `off` and `on`;
- three warm-up runs per variant, excluded from statistics;
- 44 measured pairs, 88 measured runs;
- alternating pair order `off,on` and `on,off`;
- hard child-process CPU affinity to logical CPU 0;
- exact physical output hashes after every run;
- expected legacy shadow exit code 100 recorded as fixture metadata;
- no post-hoc timing outlier deletion.

The host remained a shared virtual environment. CPU-affinity controls where the child may execute, but it does not reserve the physical processor or remove hypervisor/host interference.

## MP-B01 controlled CPU result

All 88 measured runs reproduced the same normalized physical outputs:

| Output | SHA-256 |
| --- | --- |
| `result.bal` | `8225c618e5a36243ab1a48f689c3ef09f28985bbdf501d38c6fdfb84f6fa7e7e` |
| `result.blc` | `d013c4ecc7bbdde76b5f0e03483dbc9d15e6b64c936eebe50a3e2624d5c8b66a` |

Primary child CPU comparison, `on/off - 1`:

| Statistic | Value |
| --- | ---: |
| pairs | 44 |
| mean | +1.171% |
| median | +0.091% |
| paired standard deviation | 8.527% |
| operational minimum detectable effect | 2.571% |
| predeclared target | 1.000% |
| target qualified | no |
| observed effect resolved | no |

Wall elapsed produced essentially the same rejection, with a 2.573% detection floor.

The large spread is not removed from the evidence. The largest child-CPU pair delta was +47.2% and the smallest -17.5%. This demonstrates that CPU affinity alone does not make the current host suitable for 1% performance claims.

If the observed 8.53% paired noise were stationary, about 291 pairs would be required to reach a 1% two-standard-error floor. MP-6 treats that as evidence to improve the host, not as a reason to spend hundreds of extra runs on a noisy shared machine.

## Qualification result

MP-6 establishes that:

- CPU and wall elapsed metrics are now semantically distinct;
- a benchmark must predeclare its desired resolution;
- pair count can be derived from pilot variance rather than guessed;
- CPU affinity is enforceable in the benchmark runner;
- physical equality remains a mandatory gate;
- the current shared host fails the predeclared 1% CPU resolution target;
- therefore the +1.17% mean is **not** a qualified observer-overhead estimate.

MP-6 does **not** establish:

- a 1% production CPU baseline;
- zero observer overhead;
- performance of a SWAP5 production TX/HY seam;
- MultiSWAP scaling;
- B12 performance;
- GPU suitability or speedup.

## Reusable tooling

`tools/performance/mp_cpu_baseline.py` provides:

- host metadata probing;
- validation of a predeclared CPU-baseline plan;
- pilot-based pair-count calculation;
- paired CPU and wall-time summarization;
- the operational minimum-detectable-effect and target-resolution gates.

`tools/performance/mp_cpu_runner.py` enforces the target child affinity, exact executable hash, expected exit code and output-hash collection for a versioned plan. `tools/performance/mp_cpu_pairs.py` regenerates the checked-in statistical summary from compact paired evidence.

The paired measurements, deterministic summary and evidence/provenance record are versioned under `benchmarks/performance/evidence/`.

## Integration boundary

- **MP** owns performance protocol, measurement resolution and cost evidence.
- **VQ** continues to own physical equivalence and hard mass-balance acceptance.
- **TX/HY** must expose a stable production observation seam before this protocol can qualify native SWAP5 observer cost.
- **RT** must provide stable worker/batch/template identities before the same method is applied to MultiSWAP scaling.

## Next safe step

MP-7 should move the same predeclared protocol to a genuinely quieter CPU environment: dedicated or otherwise demonstrated to meet the requested resolution, with stable affinity and complete host/frequency metadata. The run should first prove the resolution gate, then establish an MP-B01 CPU baseline.

If a VQ-qualified B12 fixture becomes available first, MP-B04 can be promoted separately, but the same performance-resolution discipline applies.
