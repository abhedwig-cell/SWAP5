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

The GNU runner is capability-limited verification infrastructure. It is not declared globally equivalent to the packaged Intel executable. Legacy BAL/BLC normalization is available through `balance.py`, but its `0.01 cm` output precision is not sufficient for the hard invariant-13 mass gate.

## Qualified predecessor snapshots

`B1.5p1` is the provenance-repaired five-fix predecessor. `B1.6` adds SWAP-009. Both remain immutable qualified historical predecessors of the current reference.

```bash
python tools/vq/b1_snapshot_identity.py --reference-root /path/to/SWAP5-checkout --pin tools/vq/cases/b1-5p1-reference-pin.json
python tools/vq/b1_snapshot_identity.py --reference-root /path/to/SWAP5-checkout --pin tools/vq/cases/b1-6-reference-pin.json
```

## Current B1.7 corrected reference

`B1.7 = B1.6 + SWAP-010` is the current corrected-reference oracle. SWAP-010 shares `WC_K_models_04_11.f90` with SWAP-009, so admission pins canonical B0 provenance and the exact ordered B1.6 preimage.

```bash
python tools/vq/b1_7_admission_gate.py
python tools/vq/b1_7_reconstruct.py --archive /path/to/SWAP_4.3.1.zip --output-dir /tmp/B1.7/SWAP
```

Expected B1.7 source identity:

```text
members          63
source bytes      1,860,091
manifest SHA-256  62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba
```

`docs/verification/expected-differences.json` defines admitted B0 -> B1.7 difference envelopes. Unregistered differences remain qualification failures.

## B2 reference admission

Before a numerical B1.7 -> B2 comparison can run, the checkout must pass the fail-closed candidate gate:

```bash
python tools/vq/b2_reference_gate.py \
  --repo-root /path/to/SWAP5-checkout \
  --candidate tools/vq/cases/b2-reference-candidate.json
```

VQ-1d1 binds candidate and stored evidence to the current `b1-manifest.yml`, including source-manifest identity and the pinned B2 observation commit.

For a candidate marked `READY_FOR_VQ_B1_TO_B2`, VQ-1d2 additionally requires a valid `SWAP5-B2-reference-seam-v1` declaration:

```bash
python tools/vq/b2_seam_contract.py \
  --repo-root /path/to/SWAP5-checkout \
  --contract /path/to/integrated/reference-seam.json
```

The seam binds the exact implementation commit, entrypoint, reference policy, explicit parameters/state/forcing/numerical configuration, generic `[t0,t1]`, transactional rollback safety, unrounded mass accounting, diagnostics, and the absence of hidden kernel file/path/MODFLOW-tile/calendar dependencies.

VQ-1d3 requires the seam's result contract to satisfy `SWAP5-B2-reference-result-v1` on the same exact implementation commit:

```bash
python tools/vq/b2_result_contract.py \
  --repo-root /path/to/SWAP5-checkout \
  --contract /path/to/integrated/reference-result.contract.json
```

Accepted production results are normalized to `SWAP5-B2-reference-result-record-v1` and checked with:

```bash
python tools/vq/b2_result_record.py --record /path/to/normalized/result.json
```

The canonical record contains the exact interval, committed endpoint state, stable physical result IDs, unrounded mass accounting, transaction history, solver diagnostics and provenance. The record validator independently recomputes the mass residual but deliberately does not apply an unqualified universal mass tolerance.

The current real candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`; these VQ contracts do not create a synthetic production B2 seam.

## VQ-1e1 transaction and generic-time harness

The executable verifier self-test is:

```bash
python tools/vq/tx_time_harness.py \
  --fixture-suite \
  --evidence tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json
```

It runs the named harness cases:

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

The synthetic additive adapter exists only to qualify verifier behavior and fault detection. A successful fixture run reports `VERIFIER_HARNESS_ONLY`, `b2_physics_status = NOT_EVALUATED`, `production_physics_executed = false`, and `production_mass_tolerance_qualified = false`.

A future production B2 adapter may reuse the same `QualificationAdapter` protocol only after the VQ-1d reference seam/result gate passes. The fixture's exact TIME-SPLIT comparator is not a production tolerance.

## Unrounded mass accounting

The B2 normalization reuses:

```text
docs/verification/mass-accounting-contract.md
tools/vq/contracts/mass-accounting-record.schema.json
```

Hard mass conservation may not be weakened by execution policy. Rounded legacy report output is never the B2 acceptance oracle.

## Unit tests

```bash
python -m unittest \
  tools.vq.test_reference_identity \
  tools.vq.test_balance \
  tools.vq.test_b0_source_runner \
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b1_reconstruct \
  tools.vq.test_b2_result_contract \
  tools.vq.test_b2_result_record \
  tools.vq.test_b2_seam_contract \
  tools.vq.test_b2_reference_gate \
  tools.vq.test_tx_time_harness
```

Every future B1/B2 adapter must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
