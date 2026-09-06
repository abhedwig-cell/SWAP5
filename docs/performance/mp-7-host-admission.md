# MP-7 host admission for a 1% CPU baseline

**Workstream:** MP  
**Evidence-start baseline:** `d5f163534f8feb7ff7f6d1f1bcb4ce4b0d168fc5`  
**Result:** `HOST_REJECTED_FOR_1PCT_CPU_BASELINE`  
**Scope:** performance measurement infrastructure and qualification evidence only; no production physics, solver or runtime interface is changed

## Purpose

MP-6 showed that pinning MP-B01 to one logical CPU was not sufficient: the shared host still had a child-CPU minimum detectable effect (MDE) of about 2.57% against the predeclared 1% target. MP-7 therefore makes host quality an explicit admission problem rather than assuming every available CPU is equally suitable.

The host-admission procedure is versioned in `benchmarks/performance/host-admission-protocol.json`. Its evidence is summarized by `tools/performance/mp_host_admission.py`.

The protocol has three independent phases:

1. **baseline-only preflight** across all visible CPUs, without using the on/off effect to choose a CPU;
2. **paired pilot** on the selected CPU, used only to estimate paired variance and predeclare the final pair count;
3. **final paired qualification**, whose result is accepted only if every host, physical-equality and resolution gate passes.

A failed final gate is a host rejection. The same experiment may not be repaired after the fact by adding enough extra pairs to cross the requested resolution threshold.

## Preflight CPU selection

The environment exposed five logical CPUs and a cgroup CPU quota of `400000 100000`, i.e. four CPU-equivalents per 100 ms period, with cpuset `0-4`.

Four baseline-only MP-B01 measurements were made on each visible CPU after a warmup. The deterministic selection rule is: among candidates with no measured preflight throttling, select the CPU with the lowest child-process CPU-time coefficient of variation; use CPU id only as a tie-breaker.

| CPU | child-CPU CV | wall-time CV |
| ---: | ---: | ---: |
| 0 | 1.872% | 1.876% |
| 1 | 1.530% | 1.546% |
| 2 | 1.985% | 1.986% |
| **3** | **0.812%** | **0.748%** |
| 4 | 1.223% | 1.222% |

CPU3 therefore passed the preflight CV limit of 1% and was selected without looking at the measurement-on effect.

## Independent pilot and predeclared final size

A separate ten-pair on/off pilot was then run on CPU3. The pilot mean is not used as a performance result. Only the paired child-CPU standard deviation is used for experiment sizing.

The pilot paired standard deviation was `0.0225406431`, or about **2.254%**. With the established MP rule

```text
N = ceil((k * sigma / target)^2)
```

using `k = 2` and `target = 0.01`, this yields **21 predeclared final pairs**.

The ten pilot pairs are excluded from the final effect estimate.

## Final qualification

The final phase used three warmups per variant and 21 paired cycles, alternating `off,on` and `on,off`. Because the execution environment imposes a tool-call runtime bound, the 21 already-predeclared pairs were executed in three blocks of seven pairs. The block split changes neither the pair count nor the global pairing/order rule, and no measured sample was deleted or replaced.

All 42 measured runs reproduced the same normalized physical output hashes:

- `result.bal`: `8225c618e5a36243ab1a48f689c3ef09f28985bbdf501d38c6fdfb84f6fa7e7e`
- `result.blc`: `d013c4ecc7bbdde76b5f0e03483dbc9d15e6b64c936eebe50a3e2624d5c8b66a`

No post-hoc timing outlier deletion was performed.

### Child-process CPU result

| Quantity | Result |
| --- | ---: |
| final pairs | 21 |
| paired mean `on/off - 1` | +0.473% |
| paired median | -0.125% |
| paired standard deviation | 3.097% |
| MDE at `k=2` | **1.352%** |
| requested MDE | **1.000%** |

The requested resolution gate therefore **fails**. The observed +0.473% mean is not interpreted as observer overhead because the host cannot resolve a 1% effect under the predeclared rule.

The secondary wall-time MDE is about **1.340%** and also misses 1%.

## Throttling gate

No individual final measured sample recorded a cgroup throttling event. However, host admission covers the complete qualification window, including warmups and the intervals between measurement blocks.

Across that broader window the cgroup counters changed from:

- `nr_throttled = 68` to `70`;
- `throttled_usec = 3,164,826` to `3,230,196`.

That is **2 throttling events and 65,370 microseconds** during the qualification window. Consequently the host also fails the no-window-throttling gate.

This distinction is intentional: absence of throttling inside a measured process invocation does not prove that the shared execution environment was isolated throughout the experiment.

## Admission result

The machine-readable gates are:

| Gate | MP-7 |
| --- | --- |
| deterministic CPU selection | pass |
| selected CPU preflight CV <= 1% | pass |
| physical output equality | pass |
| no throttling inside measured samples | pass |
| no throttling in full qualification window | **fail** |
| final child-CPU MDE <= 1% | **fail** |

Therefore:

```text
host_admitted_for_cpu_baseline = false
cpu_baseline_established       = false
```

MP-7 improves the attainable MDE from the MP-6 value of about 2.57% to about 1.35%, so deterministic CPU selection is useful. It is not sufficient to convert this shared virtual host into a 1%-quality performance environment.

## What MP-7 does not claim

MP-7 does **not** claim:

- that observer overhead is +0.473%, zero, or any other precise value;
- that CPU3 is generally faster or better than the other CPUs beyond this preflight window;
- that the GNU B0 shadow executable is the SWAP5 production performance baseline;
- that B1.5p1 is an executable corrected-reference oracle while its VQ identity gate remains pending;
- that B12 is executable; MP-B04 remains parameter-locked;
- any MultiSWAP scaling or GPU result.

## Reproducibility

Versioned evidence:

- `benchmarks/performance/host-admission-protocol.json`;
- `benchmarks/performance/evidence/mp-b01-host-admission.evidence.json`;
- `benchmarks/performance/evidence/mp-b01-host-admission.summary.json`.

CI reruns the deterministic summary from the compact preflight, pilot and final evidence and requires byte-identical agreement with the checked-in summary. Unit tests cover deterministic CPU selection, successful admission of a clean synthetic host, fail-closed selection, window throttling rejection and the requirement to re-predeclare pair count when the target changes.

## Architecture invariant review

Affected invariants: **3, 5, 6, 13, 16, 23, 24, 25, 26, 30**.

MP-7 strengthens rather than relaxes them: measurement environment quality is explicit and diagnosable, physical configuration remains separate from performance policy, mass/physical equality remains mandatory evidence, and no throughput claim is allowed to bypass reference-mode qualification.

## Next safe step

**MP-8:** execute the same admission protocol on an actually isolated performance environment, preferably a dedicated/self-hosted runner or bare-metal/VM allocation with reserved CPU resources and stable frequency metadata. The first objective is only to pass the 1% host-admission gate. Establish an MP-B01 CPU baseline only after that gate passes.

If VQ qualifies a complete B12 difficult-column fixture first, MP-B04 can be promoted independently, but its performance evidence remains subject to the same host-admission discipline.
