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

`B1.5p1`, `B1.6` and `B1.7` remain immutable qualified historical predecessors. Their exact identities can be checked with the corresponding pins under `tools/vq/cases/` using `b1_snapshot_identity.py`.

## Current B1.8 corrected reference

`B1.8` is the current corrected-reference oracle:

```text
B1.8 = B1.7 + SWAP-013
```

SWAP-013 targets `readswap.f90`, which is unchanged by B1.1-B1.7, so its ordered B1.7 preimage is identical to canonical B0. The correction adds only the PDI model 8-11 `0 < HA < H0` validation guard after the existing magnitude conversion.

Repository admission bookkeeping is checked by:

```bash
python tools/vq/b1_8_admission_gate.py
```

The exact source-bound guard gate, including a strict GNU Fortran 9-case harness, is:

```bash
python reference/swap-4.3.1/patches/SWAP-013/tests/run_guard_gate.py
```

Exact source reconstruction from canonical B0 is available through:

```bash
python tools/vq/b1_8_reconstruct.py \
  --archive /path/to/SWAP_4.3.1.zip \
  --output-dir /tmp/B1.8/SWAP
```

Expected final source identity:

```text
members          63
source bytes      1,860,493
manifest SHA-256  e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae
```

SWAP-013 changes only invalid-input acceptance/rejection. Valid PDI constitutive equations, non-PDI models, solver policy, time integration and water-balance equations are unchanged.

## Expected differences

`docs/verification/expected-differences.json` defines the admitted B0 -> B1.8 difference envelopes. Any unregistered difference remains a qualification failure. B1 is a corrected legacy reference, not a license for approximate equivalence.

## B2 reference admission

Before a numerical B1.8 -> B2 comparison can run, the checkout must pass the fail-closed candidate gate:

```bash
python tools/vq/b2_reference_gate.py \
  --repo-root /path/to/SWAP5-checkout \
  --candidate tools/vq/cases/b2-reference-candidate.json
```

VQ-1d1 reads the current B1 oracle from `reference/swap-4.3.1/b1-manifest.yml`, requires candidate snapshot/status/source-manifest identity to match it, binds the production observation commit, and can compare the live fail-closed projection against stored gate evidence.

For a candidate marked `READY_FOR_VQ_B1_TO_B2`, VQ-1d2 additionally requires a valid `SWAP5-B2-reference-seam-v1` declaration:

```bash
python tools/vq/b2_seam_contract.py \
  --repo-root /path/to/SWAP5-checkout \
  --contract /path/to/integrated/reference-seam.json
```

The seam binds exact implementation commit, entrypoint, full-accuracy reference policy, explicit parameters/state/forcing/numerical configuration, generic `[t0,t1]`, rollback-safe transaction semantics, unrounded mass accounting, diagnostics, and absence of hidden kernel file/path/MODFLOW-tile/calendar dependencies.

VQ-1d3 requires the seam's result declaration to satisfy `SWAP5-B2-reference-result-v1` on the same exact implementation commit:

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

The current real candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`. The VQ contracts do not create a synthetic production B2 seam.

## VQ-1e1 transaction and generic-time harness

The executable verifier self-test is:

```bash
python tools/vq/tx_time_harness.py \
  --fixture-suite \
  --evidence tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json
```

It runs:

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

The integrated VQ reference workflow runs the current B1.8 admission/guard gates plus:

```bash
python -m unittest \
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b2_result_contract \
  tools.vq.test_b2_result_record \
  tools.vq.test_b2_seam_contract \
  tools.vq.test_b2_reference_gate \
  tools.vq.test_tx_time_harness
```

Every future B1/B2 adapter must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
