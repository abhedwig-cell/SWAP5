# PPA-WU05-C3A PERF03 bounded cost attribution

Date: 2026-10-11

Status: **QUALIFIED RESEARCH MEASUREMENT, NO PRODUCTION OPTIMIZATION**.

The frozen question in [PERF03 preregistration](PPA_WU05C3A_PERF03_PREREGISTRATION.md) is answered for one explicitly non-skipped stress fixture. Source snapshot is canonical `8acdf60e1da367f482fe9d2aadb9a849670b69b8`. Remote scientific checkpoint `0731bdadc656b0a7f086bb1d9ce5188c46faf0c0`, tree `07a782843d7ce69b9465ef003e2871f401ef48fc`, was persisted before execution. No production source, equation, tolerance or ownership changed.

## Fixture and actual qualification

The same production dataset constructor feeds all four measured partitions. All three nodes use h=-75cm, theta=0.40 and293K; soil/material and root carriers follow the canonical typed benchmark construction, with explicit real64 literals. Atmospheric oxygen boundary is0.27. This synthetic state fixes pressure head and water content independently; it is not an accepted hydrological field trajectory. The PERF02 sufficient-condition gate is checked false before measurement. All three normalized factors are zero, while each node executes31 actual residual callbacks through the admitted scalar bisection. The MICRO/MACRO residual path is therefore exercised, rather than skipped by a no-stress shortcut.

REFERENCE waterfilm, assembly using that precomputed waterfilm, profile using those assembled inputs, and the complete current factor-from-state route all share this exact fixture. Unchanged profile/full factors agree bit-exactly. A temporary diagnostic response-module copy increments one counter at each actual residual callback. Its O0/O2 factors agree byte-exactly with the corresponding unmodified build. O0/O2 scientific outputs and counts also agree byte-exactly in this execution. Instrumentation is excluded from every timing build and does not enter repository production source.

## Local timing result

GNU Fortran13.3.0, `-O3 -march=native`, AMD EPYC9V74 shared x86_64 container. Each independent stage has100 warmups and5000 measured evaluations; seven process repetitions are retained. Times below are medians across those seven runs, not portable guarantees.

| Partition | Median per evaluation | Fraction of complete route |
| --- | ---: | ---: |
| REFERENCE waterfilm | 69.685us | 87.45% |
| Assembly after precomputed waterfilm | 0.338us | 0.42% |
| Profile MICRO/MACRO and bisection | 8.967us | 11.25% |
| Complete current factor route | 79.682us | 100% |

The three stage medians sum to99.13% of the complete-route median. Independent timings need not sum exactly: the full route includes validation and the negative PERF02 gate, and runs have timing noise. These are inclusive partition costs; no subroutine-level profile or confidence interval is claimed.

Waterfilm dominates this fixture. Assembly alone is below the preregistered approximately5% materiality threshold. The next owner investigation is exact-preserving elimination of repeated pure work in waterfilm, with source-bound numerical identity. This result does not admit an optimization or authorize approximation, altered quadrature tolerances, broad caching, new state or ABI changes. Profile cost is secondary but still above5% here.

No growing-season frequency, realistic application speedup or MultiSWAP scaling claim follows from this single synthetic fixture. Broader fixtures were optional in the preregistration and are not used to select a more favorable result. Existing E2E timing remains separate application evidence.

## Preserved original and reproducible successor

Original PR1008 head `f4f698ddfe2c12d2676afc7e11347bb9410a08be` has four unique postimages. All four are preserved verbatim, including its seven-head quadrature characterizer and workflow, without importing that workflow. The original Python dependency regex contains doubled backslashes and cannot discover the expected modules. The new research runner uses actual module/use patterns and pins every compiled source SHA256. The frozen preregistration is retained verbatim; no retrospective decision-rule edit is made.

The31-member archive `integration/audits/evidence/PPA_WU05C3A_PERF03_ATTRIBUTION_20261011.tar.gz.b64`, decoded SHA256 `85811abdc61e2842ebca00a6478bbce6246a68aadfa8abf07600c3f104d6cefe`, preserves all four original files, every qualified compile input, the research runner, complete scientific/timing JSON, raw execution log, CPU report and manifest. Full machine-readable result is `integration/audits/PPA_WU05C3A_PERF03_ATTRIBUTION_20261011.json`. The original branch/head remains reachable after research-carrier closure.

Rerun with `python tests/performance/run_bartholomeus_perf03_attribution.py --result /tmp/perf03-result.json`. This runs focused O0/O2 identity/count diagnostics followed by seven uninstrumented O3 timing repetitions. Timing values can change on another host. The existing registry closure entry owns admission and recovery; zero production capabilities are added.
