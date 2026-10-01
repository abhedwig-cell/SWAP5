# F-PE-MULTI08 P2 — local execution environment result

Date: 2026-10-01

Status: BLOCKED_BY_REPOSITORY_MATERIALIZATION

## Available compute host

The available local execution host was inspected before using CI:

- logical CPUs visible: 5;
- GNU Fortran: 14.2.0;
- git: 2.47.3;
- frozen BRO artifact successfully materialized locally:
  `multi08-pdok.zip`, 75,395,943 bytes.

This host is suitable for a local 1/2/4 harness-identity qualification. It is
not suitable for the requested 8/16/24+ production scaling frontier.

## Execution attempt

A direct repository clone from the compute container was attempted in order to
run the already-persisted MULTI08 benchmark branch.

The container has no external DNS/network access and returned:

`Could not resolve host: github.com`.

No SWAP5 checkout is mounted in the compute container.

Therefore the branch source cannot currently be materialized into the local
compiler environment through the available connector/container bridge.

## Interpretation

This is an infrastructure/materialization blocker, not a numerical,
compilation, worker-pool or physics failure.

Do not substitute GitHub-hosted CI timing for the missing multicore host
evidence.

## What is already ready

Repository branch:
`research/f-pe-multi08-production-scaling-frontier`

Executable:
`tests/fpe/run_fpe_multi08_scaling_frontier.sh`

Frozen BRO artifact authority:
workflow run `36550782840`, artifact
`f-pe-elastic12a4-pdok-atom`.

## Next safe execution

On any checked-out SWAP5 host with gfortran/OpenMP and the artifact unpacked:

```bash
bash tests/fpe/run_fpe_multi08_scaling_frontier.sh <artifact-dir>
```

For the full issue #668 frontier, prefer a host with at least 24 independently
usable hardware threads. The current 5-CPU host can only establish the
1/2/4 qualification subset.
