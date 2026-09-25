# F-PE-ZERO-WASTE01 — zero-waste tranche checkpoint

Date: 2026-09-25

Source head at evidence review: `ecc99898c7259138eac32751ce0b3bb1e03195c3`

Status: `QUALIFIED_PERFORMANCE_CHECKPOINT_WITH_OPEN_CI_HARNESS_REPAIR`

## End-to-end paired runtime result

The paired H03 application-host benchmark compares the preregistered baseline and current zero-waste candidate on the same runner and workload, using 10 paired repetitions of 5,000 intervals.

Reference mode:

- paired mean ratio: 0.891611793;
- paired median ratio: 0.890779915;
- paired mean speedup: 10.838821%;
- paired mean delta: -1355.148860 ns/interval;
- nonlinear iterations per solve: 1;
- constitutive evaluations per solve: 2;
- gate: PASS.

Directional mode:

- paired mean ratio: 0.905390812;
- paired median ratio: 0.906503121;
- paired mean speedup: 9.460919%;
- paired mean delta: -2072.116380 ns/interval;
- nonlinear iterations per solve: 1;
- constitutive evaluations per solve: 2;
- gate: PASS.

These are workload-specific shared-runner results, not portable universal SWAP5 speedup claims.

## Exact-zero-work evidence

Current compute-core gates report:

- workspace full resets per solve: 0;
- workspace zeroed bytes per solve: 0;
- workspace full resets per full/half interval: 0;
- workspace zeroed bytes per interval: 0;
- physical identity gate: PASS;
- O0/O2 runtime-output identity: PASS;
- poisoned-workspace equivalence: PASS.

## Large-N dispatch evidence

At N=R=10,000, shared-runner microbenchmarks reported:

- legacy receipt validation: ~39.63 ms/dispatch, structural work count 149,995,000;
- legacy receipt lookup: ~31.37 ms/dispatch, structural work count 50,005,000;
- indexed receipt preparation/lookup: ~0.0602 ms/dispatch, work count 30,000;
- exact execution-plan match: ~0.0148 ms/dispatch versus full registry validation ~31.36 ms/dispatch.

The portable conclusion is the structural complexity reduction, not the exact timing ratio.

## State-materialization negative priority result

State-copy microbenchmarks show that the isolated copy/allocation cost is small relative to the remaining interval runtime:

- n=60, three fresh full/half materializations: ~85 ns;
- n=200: ~235 ns;
- n=1000: ~455 ns.

The three transaction states are semantically required for current exact full/half isolation. No clone-elimination repair is authorized from this evidence.

## Current interpretation

The zero-waste tranche has now produced a measurable approximately 10% end-to-end improvement on the H03 workload while leaving the solver trajectory unchanged.

As overhead is removed, remaining optimization priority must shift toward work that is still repeated every interval or every physical solve.

A particularly visible remaining exact-cost path is parameter configuration:

1. the current parameter object is validated/prepared;
2. geometry is copied into worker-local storage;
3. prepared hydraulic coefficients are compatibility-scanned against the raw 24-row input;
4. prepared hydraulic storage is copied into the worker model.

The parameter preprocessing benchmark for n=60 measured:

- full MvG preprocessing: ~2556 ns/call;
- prepared-registry exact scan: ~494 ns/call;
- prepared copy: hundreds of ns/call;
- geometry copy: ~28 ns/call.

The production bootstrap already performs one-time preprocessing. Therefore the next P0 question is not whether preprocessing should be repeated; it is whether exact identity/revision semantics can allow worker-local parameter binding to avoid repeated full compatibility scans and large prepared-array copies when the same immutable parameter object is reused.

No such immutability shortcut is admitted yet.

## Next work

`H22: exact parameter-binding identity / revision audit`

Questions:

- Are production application parameter objects immutable after initialization?
- Can the worker remember the exact parameter-object identity or an explicit generation/revision?
- Can same-generation configuration skip geometry/hydraulic recopy while preserving generic fallback for arbitrary callers?
- What is the measured end-to-end gain?
- Does switching between columns/parameter sets invalidate the binding deterministically?

Until these are proven, generic callers retain full refresh semantics.
