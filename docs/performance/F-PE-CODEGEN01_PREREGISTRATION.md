# F-PE-CODEGEN01 — compiler/code-generation performance frontier

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Canonical parent:
`integration/f-ci-canonical@933ea3824c9fbfe74c551d6d6fe8144f39b6c378`

Branch:
`work/f-pe-codegen01-compiler-frontier`

## Purpose

Measure whether compiler/code-generation choices can produce material end-to-end production-shaped MultiSWAP speedup without changing SWAP source semantics.

## Frozen variants

Compile the same production-shaped workload under:

1. `BASE_O2`
   - `-O2`

2. `O3`
   - `-O3`

3. `O3_NATIVE`
   - `-O3 -march=native`

4. `O3_NATIVE_LTO`
   - `-O3 -march=native -flto`

The host identity and CPU model must be recorded.

## Workload

Use the admitted production-groundwater application-context scaling fixture.

Primary:
- N=10,000;
- workers=4;
- 5 timing repetitions.

Secondary:
- worker=1 at N=10,000 to distinguish single-thread codegen from parallel-runtime effects.

## Semantics

Every candidate must preserve:
- exact q checksum;
- exact tangent checksum;
- deterministic repeated output;
- successful transaction/candidate lifecycle.

Any semantic mismatch rejects the compiler variant.

## Measurement rule

Compilation time is excluded.

Use median steady-state trial wall-clock after warm-up.

Report:
- worker=1 wall and throughput;
- worker=4 wall and throughput;
- speedup versus BASE_O2 at each worker count.

## Selection rule

A candidate advances only if:
- worker=4 end-to-end speedup >=5%; and
- worker=1 is not more than 2% slower; and
- semantics are exact.

If multiple variants pass, select the fastest portable variant first:
- prefer O3 over native;
- prefer native only if O3 does not capture most of the gain;
- prefer LTO only if it adds >=3% beyond the best non-LTO candidate.

## Production boundary

Research-only compiler qualification.

No source, physics, tolerance, solver, temporal, tangent, scheduling, coupling, transaction or publication change.

A host-specific `-march=native` result is not automatically portable production authority.
