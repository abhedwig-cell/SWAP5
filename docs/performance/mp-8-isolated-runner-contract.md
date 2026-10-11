# MP-8 isolated performance-runner contract

**Workstream:** MP  
**Evidence-start baseline:** `8eb863eadbae5f505188d2d6d9404c66fd1b1446`  
**Status:** `INFRASTRUCTURE_PENDING`  
**Scope:** performance infrastructure and qualification gating only; no production physics, solver, runtime or coupler interface is changed

## Purpose

MP-7 proved that better CPU selection can materially improve measurement resolution, but the current shared execution host still failed the predeclared 1% child-CPU resolution gate and accumulated cgroup throttling during the qualification window. MP-8 therefore stops treating “a quieter CPU” as sufficient and defines what an isolated performance runner must prove before the MP-7 admission experiment is allowed to establish a CPU baseline.

The repository currently contains no repository-visible `self-hosted` performance-runner configuration. The available repository connector also does not expose account-level runner inventory. MP-8 therefore does **not** infer that a dedicated runner exists or does not exist. It records the current state as `INFRASTRUCTURE_PENDING` and prepares a fail-closed contract and manual readiness workflow for when such infrastructure is provisioned.

## Two-stage gate

MP-8 deliberately separates two questions:

1. **runner contract readiness** — is the machine provisioned in a way that is suitable for a high-quality performance experiment?
2. **host admission** — does an actual MP-B01 experiment on that machine pass the predeclared MP-7 1% resolution, physical-equality and full-window throttling gates?

A runner that passes stage 1 is still recorded with:

```text
host_admitted_for_cpu_baseline = false
cpu_baseline_established       = false
```

Only stage 2 may change those facts.

## Versioned runner contract

`benchmarks/performance/isolated-runner-contract.json` defines the current MP contract. A candidate runner is routed through the GitHub labels:

- `self-hosted`;
- `linux`;
- `x64`;
- `swap5-performance`.

The contract additionally requires machine and provisioning evidence for:

- Linux execution;
- target CPUs contained in both process affinity and the effective cgroup cpuset;
- an unbounded cgroup CPU quota (`cpu.max` starts with `max`);
- frequency-policy metadata for every target CPU;
- reservation of all SMT siblings of every measured CPU;
- Python and GNU Fortran availability;
- the exact registered B0 distribution identity;
- explicit operator attestation that the runner is dedicated to the benchmark, unrelated workloads are excluded and the frequency policy is controlled.

These are **entry requirements**, not proof that the final timing variance will be below 1%.

## Host probe

`tools/performance/mp_isolated_runner.py` records a machine-readable snapshot containing, where available:

- runner name, OS and architecture;
- kernel/platform identity;
- CPU model and hypervisor flag;
- logical CPU count;
- process affinity and effective cgroup cpuset;
- `cpu.max` and `cpu.stat`;
- kernel isolation options (`isolcpus`, `nohz_full`, `rcu_nocbs`);
- per-target-CPU frequency driver/governor/min/max metadata;
- SMT sibling topology;
- presence of `python3` and `gfortran`.

The tool validates the versioned contract and readiness record and can assess a probe snapshot together with a completed operator attestation and the machine-verified B0 identity.

The assessment can only produce `runner_contract_ready = true`. It intentionally cannot establish an MP-B01 baseline by itself.

## Reference provisioning

The manual workflow does not trust a file name or runner-local path as reference identity. The operator supplies the path to the SWAP 4.3.1 distribution, and the existing MP-3A B0 verifier checks the exact registered distribution/source/executable hashes before runner readiness can pass.

This keeps the external runner dependency explicit and avoids a silent “whatever archive happens to be installed” assumption.

B1.5p1 remains the current corrected legacy definition, but its exact oracle status is still `PENDING_VQ_IDENTITY_GATE`. MP-8 therefore does not use B1.5p1 as an executable corrected-reference oracle. The newly qualified targeted SWAP-009 gate also remains outside B1 pending its stated VQ admission gates.

## Operator attestation

`benchmarks/performance/isolated-runner-attestation.template.json` is intentionally not admission-ready. A benchmark operator must replace its placeholders with evidence-backed facts. Required fields are:

- `isolation_method`;
- `reserved_cpus`;
- `runner_dedicated_to_benchmark = true`;
- `unrelated_workloads_excluded = true`;
- `frequency_policy_controlled = true`.

For SMT systems, `reserved_cpus` must include every sibling thread of each measured CPU even if only one sibling executes SWAP. This avoids benchmarking on one logical thread while an uncontrolled workload runs on the sibling of the same physical core.

## Manual readiness workflow

`.github/workflows/performance-isolated-readiness.yml` is `workflow_dispatch` only. It is deliberately not part of normal PR or `main` CI because no qualifying self-hosted runner is currently evidenced.

The workflow targets `[self-hosted, linux, x64, swap5-performance]` and requires explicit inputs for:

- target CPU list;
- runner-local B0 distribution path;
- completed operator-attestation path.

It then:

1. validates the versioned contract and readiness record;
2. probes the runner;
3. verifies exact B0 identity;
4. assesses runner-contract readiness;
5. uploads the resulting snapshot/identity/assessment evidence;
6. fails if any readiness gate fails.

A successful workflow ends with the explicit statement that the runner is contract-ready **but not yet MP-B01 host-admitted**.

## Current readiness state

`benchmarks/performance/isolated-runner-readiness.json` currently records:

```text
status                   = INFRASTRUCTURE_PENDING
admission_evidence       = null
cpu_baseline_established = false
```

This is not a failure of SWAP or of the MP methodology. It is an explicit external infrastructure dependency. MP refuses to convert the existing shared host into a “dedicated” runner by changing thresholds or by adding more post-hoc samples.

## Relation to MP-7

The MP-7 host-admission protocol remains authoritative for the final performance gate. Once a candidate runner passes the MP-8 contract, the complete MP-7 procedure must be repeated on that same runner:

1. baseline-only CPU preflight;
2. independent paired pilot;
3. predeclared final pair count;
4. no post-hoc outlier removal or pair extension;
5. exact physical-output equality;
6. zero cgroup throttling over the full qualification window;
7. final child-CPU MDE <= 1%.

Only if all gates pass may a CPU baseline be established.

## Architecture invariant review

Affected invariants: **3, 5, 6, 13, 16, 23, 24, 25, 26, 30**.

MP-8 strengthens these invariants by keeping performance-environment policy outside the kernel, preserving physical/reference gates, making external infrastructure assumptions explicit and preventing a throughput claim from being admitted without reproducible host qualification.

## Next safe step

Provision or identify a runner that can satisfy the versioned contract, give it the `swap5-performance` label, provide a completed isolation attestation and the exact B0 distribution, and execute the manual readiness workflow.

If that readiness gate passes, repeat the full MP-7 host-admission experiment on that runner. **Do not start MultiSWAP scaling or a GPU comparison until the 1% MP-B01 host-admission gate actually passes.**
