# VQ tools

This directory contains verification and qualification tooling only. It must not contain production SWAP physics or become a hidden production execution path.

## B0 identity and provisional runner

```bash
python tools/vq/reference_identity.py --archive /path/to/SWAP_4.3.1.zip
python tools/vq/b0_source_runner.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --work-dir /tmp/vq-b0 \
  --case 2.grassgrowth
```

The GNU runner is capability-limited verification infrastructure and is not declared globally equivalent to the packaged Intel executable.

## Current B1.10 corrected reference

```text
B1.10 = B1.9 + SWAP-002
```

SWAP-002 targets `tillage.f90`, unchanged by B1.1-B1.9. The admitted patch is isolated to `set_iTill` and explicitly excludes SWAP-003 and SWAP-004. A separately staged SWAP-004 candidate does not change the current B1.10 oracle until formally admitted.

Admission and reconstruction:

```bash
python tools/vq/b1_10_admission_gate.py
python reference/swap-4.3.1/patches/SWAP-002/tests/run_tillage_start_gate.py
python tools/vq/b1_10_reconstruct.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --output-dir /tmp/B1.10/SWAP
```

Expected source identity:

```text
members          63
source bytes      1,863,575
manifest SHA-256  2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```

## B2 reference admission: VQ-1d1..1d3

A numerical B1.10 -> B2 comparison is admitted only when the checkout contains one exact full-accuracy production target satisfying the complete reference chain:

```text
current qualified B1 manifest
  -> B2 candidate on exact commit
  -> SWAP5-B2-reference-seam-v1
  -> SWAP5-B2-reference-result-v1
  -> canonical SWAP5-B2-reference-result-record-v1
```

Run the fail-closed gate with stored-evidence consistency:

```bash
python tools/vq/b2_reference_gate.py \
  --candidate tools/vq/cases/b2-reference-candidate.json \
  --evidence tools/vq/cases/b2-reference-gate-2026-09-06.json \
  --allow-expected-blocked
```

The current production target is blocked because no integrated SWAP5/B2 reference seam exists. The gate reads the current B1 oracle from `reference/swap-4.3.1/b1-manifest.yml`; stale candidate/evidence snapshots fail.

The seam requires explicit parameters, committed state, forcing, numerical configuration and generic `[t0,t1]`, with full-accuracy `reference` policy, transaction diagnostics, unrounded mass accounting and no kernel file/path/calendar dependency.

VQ recomputes:

```text
delta_storage = end_storage - start_storage
net_external  = sum(signed external terms)
residual      = delta_storage - net_external
```

No universal production mass tolerance is introduced by these tools.

## VQ-1e1 transaction/generic-time verifier

The verifier harness exposes `VQ-QualificationAdapter-v1` and the fixed suite:

```text
TX-ROLLBACK-01
TX-COMMIT-01
TX-ACCOUNT-01
TX-RERUN-01
TX-BC-REPLAY-01
TX-WARM-01
TIME-00
TIME-06
TIME-18
TIME-36
TIME-SPLIT
```

Self-qualification:

```bash
python tools/vq/tx_time_harness.py \
  --fixture-suite \
  --evidence tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json
```

Fixture PASS is strictly `VERIFIER_HARNESS_ONLY`; production physics remains `NOT_EVALUATED`.

## VQ-1e2 production-adapter binding admission

A real bridge must satisfy `SWAP5-VQ-production-adapter-binding-v1`, bind the same exact B2 commit/entrypoint/seam/result contract/reference policy, declare `production_target=true` and `synthetic_fixture=false`, preserve transaction/time/forcing/mass semantics and not change physics.

```bash
python tools/vq/production_adapter_gate.py \
  --candidate tools/vq/cases/b2-production-adapter-candidate.json \
  --evidence tools/vq/cases/vq-1e2-production-adapter-gate-2026-09-06.json \
  --allow-expected-blocked
```

The current expected state is blocked because VQ-1d has no admitted B2 target.

## VQ-1e3 production TX/TIME execution admission

VQ-1e3 is the final pre-execution boundary. It reruns VQ-1e2 and requires a verification-side loader/factory for the admitted non-synthetic adapter plus exactly the eleven canonical case IDs.

```bash
python tools/vq/production_execution_gate.py \
  --candidate tools/vq/cases/b2-production-execution-candidate.json \
  --evidence tools/vq/cases/vq-1e3-production-execution-gate-2026-09-06.json \
  --allow-expected-blocked
```

The admission gate does not import or execute production physics. Before real execution it requires:

```text
production_execution_claimed          false
b2_physics_status                     NOT_EVALUATED
production_mass_tolerance_qualified   false
```

Only after VQ-1d, VQ-1e2 and VQ-1e3 all admit the same production target may the existing TX/TIME suite be instantiated against SWAP5. Synthetic fixture PASS must never be promoted to production PASS.

## Unit tests

```bash
python -m unittest \
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b2_result_contract \
  tools.vq.test_b2_result_record \
  tools.vq.test_b2_seam_contract \
  tools.vq.test_b2_reference_gate \
  tools.vq.test_tx_time_harness \
  tools.vq.test_production_adapter_binding \
  tools.vq.test_production_adapter_gate \
  tools.vq.test_production_execution_gate
```

Every future B1/B2 adapter and production execution must record exact source/artifact identity, implementation commit, case identity, interval, runner capability and qualification scope.
