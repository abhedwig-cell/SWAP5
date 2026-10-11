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

SWAP-002 targets `tillage.f90`, unchanged by B1.1-B1.9, so its ordered B1.9 preimage equals canonical B0. The patch is isolated to `set_iTill` and explicitly excludes SWAP-003 and SWAP-004.

Admission bookkeeping:

```bash
python tools/vq/b1_10_admission_gate.py
```

The source-bound compiled six-case tillage-start gate is:

```bash
python reference/swap-4.3.1/patches/SWAP-002/tests/run_tillage_start_gate.py
```

Exact source reconstruction from canonical B0:

```bash
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

The compiled start-state gate gives B0 3/6 and the corrected source 6/6 across before-first, exact-first, between-events, exact-second, after-final and unsorted-date cases. This is focused qualification of `set_iTill`; it is not an exhaustive validation of all tillage interactions.

## Expected differences

`docs/verification/expected-differences.json` defines the admitted B0 -> B1.10 difference envelopes. Any unregistered difference remains a qualification failure.

## B2 reference-entrypoint admission

Before a numerical B1.10 -> B2 comparison can run, the candidate checkout must pass:

```bash
python tools/vq/b2_reference_gate.py \
  --repo-root /path/to/SWAP5-checkout \
  --candidate tools/vq/cases/b2-reference-candidate.json
```

The fail-closed gate still requires an exact B2 commit, integrated callable reference-mode entrypoint, explicit reference numerical policy, canonical result contract, generic `[t0,t1]`, committed state and forcing inputs, separate numerical configuration, unrounded mass accounting and transaction diagnostics.

The current candidate remains `BLOCKED_NO_INTEGRATED_B2_ENTRYPOINT`. B1.10 changes corrected legacy tillage start-state semantics only; it does not create the missing production B2 seam.

## Unrounded mass accounting

The future B2 normalization contract remains under `docs/verification/mass-accounting-contract.md` and `tools/vq/contracts/mass-accounting-record.schema.json`. Hard mass conservation may not be weakened by execution policy.

## Unit tests

```bash
python -m unittest \
  tools.vq.test_reference_identity \
  tools.vq.test_balance \
  tools.vq.test_b0_source_runner \
  tools.vq.test_b1_snapshot_identity \
  tools.vq.test_b1_reconstruct \
  tools.vq.test_b2_reference_gate
```

Every future B1/B2 adapter must record exact source/artifact identity, case identity, interval, runner capability and qualification scope.
