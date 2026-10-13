# F-CI runtime-cost audit: measurement probe (2026-10-13)

**Status:** instrumentation draft. Not a qualified numerical result. Baseline canonical `180d1dd1643f06fc8d97dff17a1cae63ef718d02`.

## Motivation
The completed MC-MET01 moving-preservation gate records 3327.080030 seconds, but its evidence does not divide compilation, linking, model execution, and controller overhead. This total must not be called SWAP5 numerical runtime.

The existing qualified build-cache experiment shows root uncached 256.5 s (356 compiler invocations), root warm 226.5 s (0 invocations), sensor uncached 211.8 s (356 invocations), sensor warm 168.0 s (0). Compiler work matters, but warm residual still includes test harness, comparison, linking, cache-validation overhead, and scientific execution.

## Instrumentation
`tools/performance/profile_gate.py` wraps only PATH-resolved `gfortran` invocations, times each compiler process using a monotonic clock, and records gate wall time, exit status and per-compiler event durations. It does not change Fortran flags, source, files or scientific assertions. It preserves gate exit status. Existing evidence paths are never overwritten.

Example:

```bash
python3 tools/performance/profile_gate.py --output /tmp/fci-cost-management-001.json -- bash tests/mc-irr01/run_mc_irr01_management_policy.sh
```

For a comparable measurement, run the same gate without the probe (using `/usr/bin/time -v`), then with the probe, repeatedly, on pinned HEAD, same host and toolchain. Keep compiler-wrapper overhead explicit. Compare the JSON timing with the raw terminal log; store all original outputs and exit status.

This probe is intentionally *not* a solver profiler. Its compiler-duration sum is not subtractable from wall time when subprocesses overlap. A residual is not equivalent to numerical solver time. Absolute compiler paths, different compiler command names and runners that reset PATH are outside coverage.

## Next required tests
1. Syntax/smoke check and negative exit-status propagation of the tool in a complete local checkout.
2. Measure original moving F-CI subgroups on one pinned tree, recording compiler calls and remaining gate walltime, first with a narrow owner test, not the full hour-long gate.
3. Instrument actual production solver execution separately: step count, accepted/rejected/retried steps, Newton and linear iterations, wall and CPU per numerical step. Never use test-harness walltime as a proxy.
4. Run identical solver profiles on current SWAP5 and a previous admitted SWAP5 snapshot on the same compiler/hardware. If SWAP4.3.1 inputs and physics differ, report comparability limits.
5. Only after evidence, decide between reducing duplicate builds, test harness optimization, and a scientific performance regression fix.

## Governance
This is an opt-in diagnostic PR only; no production physics, tolerance, reference, workflow, or immutable qualification evidence changes. Do not merge on documentation or compiler smoke evidence alone where the governing tooling acceptance requires further proof.
