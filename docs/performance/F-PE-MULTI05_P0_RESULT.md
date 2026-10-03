# F-PE-MULTI05 P0 result — high-core scaling research

Date: 2026-09-27

Status: `P0_HOST_CAPACITY_BLOCKED`

PR:
`#670 — F-PE-MULTI05: high-core-count production-groundwater scaling`

Measured head:
`f048078605bc4ece413b8f7de3a212b1b4ada8d5`

Workflow run:
`36348059597`

## Host

GitHub Actions runner exposed:
- logical CPUs: 4;
- online CPUs: 0-3;
- threads per core: 2;
- cores per socket: 2;
- sockets: 1.

Therefore only worker counts 1, 2 and 4 are valid non-oversubscribed scaling evidence.

Requested worker counts 8, 12, 16 and 24 are retained strictly as oversubscription evidence.

## Workload

Production-shaped TEMPORAL08 application-context fixture:
- N=10,000;
- 3 timing repetitions;
- exact repeated q checksum required;
- exact repeated tangent checksum required;
- temporary research-only worker-count guard widened to 24 in compiled source copies;
- production `src/**` remained unchanged.

## Results

| Workers | Oversubscribed | Seconds | Speedup | Efficiency | Throughput columns/s | Class |
|---:|:---:|---:|---:|---:|---:|---|
| 1 | no | 0.937739037 | 1.000000 | 1.000000 | 10,663.948 | STRONG_SCALE |
| 2 | no | 0.483698245 | 1.938686 | 0.969343 | 20,674.046 | STRONG_SCALE |
| 4 | no | 0.381951371 | 2.455127 | 0.613782 | 26,181.343 | USEFUL_SCALE |
| 8 | yes | 0.386705033 | 2.424947 | 0.303118 | 25,859.503 | WEAK_SCALE |
| 12 | yes | 0.385889296 | 2.430073 | 0.202506 | 25,914.168 | SATURATED |
| 16 | yes | 0.383144396 | 2.447482 | 0.152968 | 26,099.821 | SATURATED |
| 24 | yes | 0.383478572 | 2.445349 | 0.101890 | 26,077.076 | SATURATED |

Checksums were identical for every worker count:
- q sum: `2.63219253438378223e-04`;
- tangent sum: `-1.46925912412419313e-01`.

Repeated output was deterministic in the fixture.

## Interpretation

The valid 1/2/4 curve is healthy:
- 2 workers deliver 1.94x speedup, about 97% parallel efficiency;
- 4 workers deliver 2.46x speedup, about 61% parallel efficiency.

Because the host has only two physical cores with SMT2, the change from 2 to 4 workers is principally an SMT increment rather than evidence for scaling from two to four physical cores.

The oversubscribed 8/12/16/24 points remain essentially flat around 2.43-2.45x. This is expected saturation once requested workers exceed the four visible logical CPUs. These points do not establish any limit on a genuine 8/12/16/24-core host.

The oversubscription result also gives no evidence that running many more software workers than visible hardware threads improves this workload on this host.

## Frozen decision

`HOST_CAPACITY_BLOCKED`

The P0 research harness is qualified and the semantic identity checks pass, but the available CI host cannot answer the primary high-core question.

Do not:
- call the 24-worker point a 24-core scaling result;
- infer a 24-thread production speedup from the current curve;
- weaken the high-core question into an oversubscription benchmark;
- extend production worker-count admission from this evidence.

## Required continuation

Run the unchanged frozen MULTI05 sweep on a host exposing at least 8 real/logical CPUs, preferably the intended 24-thread production-class machine.

Preferred matrix:
- N=10,000 initially;
- workers 1/2/4/8/12/16/24 subject to visible CPU count;
- N=100,000 after the high-core curve is established and resource use is acceptable.

Until such a host is available, MULTI05 is blocked by execution capacity rather than by SWAP scaling behavior.
