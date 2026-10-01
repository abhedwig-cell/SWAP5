# F-PE-MULTI08 P1 — executable harness checkpoint

Date: 2026-10-01

Status: IMPLEMENTED_NOT_EXECUTED

Branch head:
`85189aa696e036afe0c4e79e17508f72b2e44fe7`

Canonical base:
`81b7feda17f53a94ab4e5877467cc4499de6f568`

## Implemented

The branch now contains an executable research benchmark:

`tests/fpe/run_fpe_multi08_scaling_frontier.sh`

and generated Fortran workload template:

`tests/fpe/test_fpe_multi08_scaling_frontier.template.f90`.

The runner:

- retrieves no network data itself; it consumes the frozen BRO artifact;
- materializes profile 8016 using the existing qualified MULTI06 preparation;
- materializes a research-only copy of the canonical worker pool;
- changes only the hard 2/4 worker-count admission predicate in that copy;
- leaves production source untouched;
- generates populations 256/1024/4096/16384;
- defaults to workers 1/2/4/8/16/24/32/48;
- skips counts above the host OpenMP thread limit;
- records host/compiler/OpenMP metadata;
- records both internal solve wall time and whole-process wall time;
- writes raw repeat results and aggregated scaling CSV;
- fails on incomplete completion/commit, retry inconsistency or mass failure.

## Repository scope audit

Compared with canonical, the branch changes only:

- MULTI08 research documentation;
- MULTI08 test/benchmark files.

No `src/` production file is changed.

## Qualification status

Implementation exists but has not yet been executed on a checked-out repository
host with gfortran and the frozen BRO artifact.

No scaling result is claimed from this checkpoint.

## Exact execution

From the repository root, with the frozen artifact unpacked at
`<artifact-dir>`:

```bash
bash tests/fpe/run_fpe_multi08_scaling_frontier.sh <artifact-dir>
```

Outputs are written by default to `multi08-results/`.

## Next decision

A host with materially more than four usable cores is required to answer the
frontier question. A small host may still qualify the 1/2/4 research-harness
identity but cannot establish the requested production scaling frontier.
